#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

require 'strscan'

class Clojure

class Parser < StringScanner
	UNPARSED = Object.new

	IGNORE = %r(
		(?:
			//[^\n\r]*[\n\r]| # line comments
			/\* # c-style comments
			(?:
				[^*/]| # normal chars
				/[^*]| # slashes that do not start a nested comment
				\*[^/]| # asterisks that do not end this comment
				/(?=\*/) # single slash before this comment's end
			)*
			\*/ # the End of this comment
			|[ \t\r\n,]+ # whitespaces: space, horicontal tab, lf, cr, and comma
		)
	)mx

	STRING = /" ((?:[^\x0-\x1f"\\] |
		# escaped special characters:
		\\["\\\/bfnrt] |
		\\u[0-9a-fA-F]{4} |
		# match all but escaped special characters:
		\\[\x20-\x21\x23-\x2e\x30-\x5b\x5d-\x61\x63-\x65\x67-\x6d\x6f-\x71\x73\x75-\xff])*)
	"/nx

	KEYWORD = /:([^(\[{'^@`~\"\\,\s;)\]}]+)/

	INTEGER = /(-?0|-?[1-9]\d*)/

	BIGNUM = /#{INTEGER}N/

	FLOAT = /(-?
		(?:0|[1-9]\d*)
		(?:
			\.\d+(?i:e[+-]?\d+) |
			\.\d+ |
			(?i:e[+-]?\d+)
		)
	)/x

	BIGDECIMAL = /#{FLOAT}M/

	RATIONAL = /(#{INTEGER}\/#{INTEGER})/

	REGEXP = /#"((\\.|[^"])+)"/

	INSTANT = /#inst#{IGNORE}*"(.*?)"/

	VECTOR_OPEN  = /\[/
	VECTOR_CLOSE = /\]/

	LIST_OPEN  = /\(/
	LIST_CLOSE = /\)/

	SET_OPEN  = /\#\{/
	SET_CLOSE = /\}/

	HASH_OPEN  = /\{/
	HASH_CLOSE = /\}/

	TRUE  = /true/
	FALSE = /false/
	NIL   = /nil/

	def initialize (source, options = {})
		super(source)

		@hash_class   = options[:hash_class]   || Hash
		@vector_class = options[:vector_class] || Array
		@list_class   = options[:list_class]   || Array
		@set_class    = options[:set_class]    || Array
	end

	alias source string

	def parsable? (what)
		!!case what
			when :vector then scan(VECTOR_OPEN)
			when :list   then scan(LIST_OPEN)
			when :set    then scan(SET_OPEN)
			when :hash   then scan(HASH_OPEN)
		end
	end

	def parse (check = true)
		reset if check

		result = case
			when parsable?(:vector) then parse_vector
			when parsable?(:list)   then parse_list
			when parsable?(:set)    then parse_set
			when parsable?(:hash)   then parse_hash
			else                         parse_value
		end

		if check && result == UNPARSED
			raise SyntaxError, 'the string does not contain proper clojure'
		end

		result
	end

	def parse_value
		case
			when scan(RATIONAL)   then Rational(self[1])
			when scan(BIGDECIMAL) then require 'bigdecimal'; BigDecimal(self[1])
			when scan(FLOAT)      then Float(self[1])
			when scan(BIGNUM)     then Integer(self[1])
			when scan(INTEGER)    then Integer(self[1])
			when scan(REGEXP)     then /#{self[1]}/
			when scan(INSTANT)    then DateTime.rfc3339(self[1])
			when scan(STRING)     then parse_string
			when scan(KEYWORD)    then self[1].to_sym
			when scan(TRUE)       then true
			when scan(FALSE)      then false
			when scan(NIL)        then nil
			else                  UNPARSED
		end
	end

	# Unescape characters in strings.
	UNESCAPE_MAP = Hash.new { |h, k| h[k] = k.chr }
	UNESCAPE_MAP.update({
		?"  => '"',
		?\\ => '\\',
		?/  => '/',
		?b  => "\b",
		?f  => "\f",
		?n  => "\n",
		?r  => "\r",
		?t  => "\t",
		?u  => nil,
	})

	EMPTY_8BIT_STRING = ''

	if EMPTY_8BIT_STRING.respond_to? :force_encoding
		EMPTY_8BIT_STRING.force_encoding Encoding::ASCII_8BIT
	end

	def parse_string
		return '' if self[1].empty?

		self[1].gsub(%r((?:\\[\\bfnrt"/]|(?:\\u(?:[A-Fa-f\d]{4}))+|\\[\x20-\xff]))n) {|escape|
			if u = UNESCAPE_MAP[$&[1]]
				next u
			end

			bytes = EMPTY_8BIT_STRING.dup

			i = 0
			while escape[6 * i] == ?\\ && escape[6 * i + 1] == ?u
				bytes << escape[6 * i + 2, 2].to_i(16) << escape[6 * i + 4, 2].to_i(16)

				i += 1
			end

			if bytes.respond_to? :force_encoding
				bytes.force_encoding 'UTF-16be'
				bytes.encode 'UTF-8'
			else
				bytes
			end
		}
	end

	def parse_vector
		result = @vector_class.new

		until eos?
			case
			when (value = parse(false)) != UNPARSED
				result << value
			when scan(VECTOR_CLOSE)
				break
			when skip(/#{IGNORE}+/)
				;
			else
				raise SyntaxError, 'wat do'
			end
		end

		result
	end

	def parse_list
		result = @list_class.new

		until eos?
			case
			when (value = parse(false)) != UNPARSED
				result << value
			when scan(LIST_CLOSE)
				break
			when skip(/#{IGNORE}+/)
				;
			else
				raise SyntaxError, 'wat do'
			end
		end

		result
	end

	def parse_set
		result = @set_class.new

		until eos?
			case
			when (value = parse(false)) != UNPARSED
				result << value
			when scan(SET_CLOSE)
				break
			when skip(/#{IGNORE}+/)
				;
			else
				raise SyntaxError, 'wat do'
			end
		end

		if result.uniq!
			raise SyntaxError, 'the set contains non unique values'
		end

		result
	end

	def parse_hash
		result = @hash_class.new

		until eos?
			case
			when (key = parse(false)) != UNPARSED
				skip(/#{IGNORE}*/)

				if (value = parse(false)) == UNPARSED
					raise SyntaxError, 'no value for the hash'
				end

				result[key] = value
			when scan(HASH_CLOSE)
				break
			when skip(/#{IGNORE}+/)
				;
			else
				raise SyntaxError, 'wat do'
			end
		end

		result
	end
end

end
