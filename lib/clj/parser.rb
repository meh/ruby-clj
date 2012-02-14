#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

require 'stringio'

class Clojure

class Parser
	NUMBERS = '0' .. '9'

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

	def initialize (source, options = {})
		@source  = source.is_a?(String) ? StringIO.new(source) : source
		@options = options

		@map_class    = options[:map_class]    || Hash
		@vector_class = options[:vector_class] || Array
		@list_class   = options[:list_class]   || Array
		@set_class    = options[:set_class]    || Array
	end

	def parse
		read_next
	end

private
	def next_type (ch)
		case ch
		when NUMBERS, '-', '+' then :number
		when 't', 'f'           then :boolean
		when 'n'                then :nil
		when '\\'               then :char
		when ':'                then :keyword
		when '"'                then :string
		when '{'                then :map
		when '('                then :list
		when '['                then :vector
		when '#'
			case @source.read(1)
			when 'i' then :instant
			when '{' then :set
			when '"' then :regexp
			end
		end or raise SyntaxError, 'unknown type'
	end

	def read_next
		ch = ignore(false)

		raise SyntaxError, 'unexpected EOF' unless ch

		__send__ "read_#{next_type ch}", ch
	end

	def read_nil (ch)
		check = @source.read(2)

		if check.bytesize != 2
			raise SyntaxError, 'unexpected EOF'
		elsif check != 'il'
			raise SyntaxError, "expected nil, found n#{check}"
		end

		nil
	end

	def read_boolean (ch)
		if ch == 't'
			check = @source.read(3)

			if check.bytesize != 3
				raise SyntaxError, 'unexpected EOF'
			elsif check != 'rue'
				raise SyntaxError, "expected true, found t#{check}"
			end

			true
		else
			check = @source.read(4)

			if check.bytesize != 4
				raise SyntaxError, 'unexpected EOF'
			elsif check != 'alse'
				raise SyntaxError, "expected false, found f#{check}"
			end

			false
		end
	end

	def read_number (ch)
		piece = ch

		while (ch = @source.read(1)) && !both?(ch)
			piece << ch
		end

		revert(ch)

		if piece.include? '/'
			Rational(piece)
		elsif piece.include? 'r'
			base, number = piece.split('r', 2)

			number.to_i(base.to_i)
		elsif piece.include? '.' or piece.include? 'e' or piece.end_with? 'M'
			if piece.end_with? 'M'
				piece[-1] = ''

				BigDecimal(piece)
			else
				Float(piece)
			end
		else
			if piece.end_with? 'N'
				piece[-1] = ''
			end

			Integer(piece)
		end
	end

	def read_char (ch)
		ch = @source.read(1)

		unescape(if ch == 'u' && lookahead(1) =~ /[0-9a-fA-F]/
			"\\u#{@source.read(4)}"
		else
			ch
		end)
	end

	def read_keyword (ch)
		result = ''

		while (ch = @source.read(1)) && !keyword?(ch)
			result << ch
		end

		revert(ch)

		result.to_sym
	end

	def read_string (ch)
		result = ''

		while (ch = @source.read(1)) != '"'
			raise SyntaxError, 'unexpected EOF' unless ch

			result << ch

			if ch == '\\'
				result << @source.read(1)
			end
		end

		unescape(result)
	end

	def read_instant (ch)
		@source.read(3)

		DateTime.rfc3339(read_string(ignore(false)))
	end

	def read_regexp (ch)
		result = ''

		while (ch = @source.read(1)) != '"'
			raise SyntaxError, 'unexpected EOF' unless ch

			result << ch

			if ch == '\\'
				result << @source.read(1)
			end
		end

		/#{result}/
	end

	def read_list (ch)
		result = @list_class.new

		ignore

		while lookahead(1) != ')'
			result << read_next
			ignore
		end

		@source.read(1)

		result
	end

	def read_vector (ch)
		result = @vector_class.new

		ignore

		while lookahead(1) != ']'
			result << read_next
			ignore
		end

		@source.read(1)

		result
	end

	def read_set (ch)
		result = @set_class.new

		ignore

		while lookahead(1) != '}'
			result << read_next
			ignore
		end

		@source.read(1)

		if result.uniq!
			raise SyntaxError, 'the set contains non unique values'
		end

		result
	end

	def read_map (ch)
		result = @map_class.new

		ignore

		while lookahead(1) != '}'
			key = read_next
			ignore
			value = read_next

			result[key] = value
		end

		@source.read(1)

		result
	end

	def unescape (string)
		string.gsub(%r((?:\\[\\bfnrt"/]|(?:\\u(?:[A-Fa-f\d]{4}))+|\\[\x20-\xff]))n) {|escape|
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

	def lookahead (length = nil)
		original = @source.tell
		result   = @source.read(length)

		@source.seek(original)

		result
	end

	def ignore (rev = true)
		while ignore?(ch = @source.read(1)); end

		rev ? revert(ch) : ch if ch
	end

	def revert (ch)
		@source.seek -1, IO::SEEK_CUR if ch
	end

	def ignore? (ch)
		if ch == ' ' || ch == ',' || ch == "\n" || ch == "\r" || ch == "\t"
			true
		else
			false
		end
	end

	def both? (ch)
		if ch == ' ' || ch == ',' || ch == '"' || ch == '{' || ch == '}' || ch == '(' || ch == ')' || ch == '[' || ch == ']' || ch == '#' || ch == "\n" || ch == "\r" || ch == "\t"
			true
		else
			false
		end
	end

	def keyword? (ch)
		if ch == ' ' || ch == ',' || ch == '"' || ch == '{' || ch == '}' || ch == '(' || ch == ')' || ch == '[' || ch == ']' || ch == '#' || ch == "'" || ch == '^' || ch == '@' || ch == '`' || ch == '~' || ch == '\\' || ch == ';' || ch == "\n" || ch == "\r" || ch == "\t"
			true
		else
			false
		end
	end
end

end
