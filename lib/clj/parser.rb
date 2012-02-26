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

module Clojure

class Parser
	NUMBERS = '0' .. '9'

	STRING_REGEX  = %r((?:\\[\\bfnrt"/]|(?:\\u(?:[A-Fa-f\d]{4}))+|\\[\x20-\xff]))n
	UNICODE_REGEX = /u([0-9|a-f|A-F]{4})/
	OCTAL_REGEX   = /o([0-3][0-7]?[0-7]?)/

	# Unescape characters in strings.
	UNESCAPE_MAP = Hash.new { |h, k| h[k] = k.chr }
	UNESCAPE_MAP.merge!(
		?"  => '"',
		?\\ => '\\',
		?/  => '/',
		?b  => "\b",
		?f  => "\f",
		?n  => "\n",
		?r  => "\r",
		?t  => "\t",
		?u  => nil
	)

	EMPTY_8BIT_STRING = ''

	if EMPTY_8BIT_STRING.respond_to? :force_encoding
		EMPTY_8BIT_STRING.force_encoding Encoding::ASCII_8BIT
	end

	def initialize (source, options = {})
		@source  = source.is_a?(String) ? StringIO.new(source) : source
		@options = options

		@map_class    = options[:map_class]    || Clojure::Map
		@vector_class = options[:vector_class] || Clojure::Vector
		@list_class   = options[:list_class]   || Clojure::List
		@set_class    = options[:set_class]    || Clojure::Set
	end

	def parse
		read_next
	end

private
	def next_type (ch)
		case ch
		when '^'               then :metadata
		when NUMBERS, '-', '+' then :number
		when 't', 'f'          then :boolean
		when 'n'               then :nil
		when '\\'              then :char
		when ':'               then :keyword
		when '"'               then :string
		when '{'               then :map
		when '('               then :list
		when '['               then :vector
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

	def read_metadata (ch)
		metadatas = [read_next]

		while lookahead(1) == '^'
			raise SyntaxError, 'unexpected EOF' unless @source.read(1)

			metadatas.push(read_next)
		end

		value = read_next

		unless value.respond_to? :metadata=
			raise SyntaxError, 'the object cannot hold metadata'
		end

		metadatas.each { |m| value.metadata = m }

		value
	end

	def read_nil (ch)
		check = @source.read(2)

		if check.length != 2
			raise SyntaxError, 'unexpected EOF'
		elsif check != 'il'
			raise SyntaxError, "expected nil, found n#{check}"
		end

		nil
	end

	def read_boolean (ch)
		if ch == 't'
			check = @source.read(3)

			if check.length != 3
				raise SyntaxError, 'unexpected EOF'
			elsif check != 'rue'
				raise SyntaxError, "expected true, found t#{check}"
			end

			true
		else
			check = @source.read(4)

			if check.length != 4
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

		revert if ch

		if piece.include? '/'
			Rational(piece)
		elsif piece.include? 'r' or piece.include? 'R'
			base, number = piece.split(/r/i, 2)

			number.to_i(base.to_i)
		elsif piece.include? '.' or piece.include? 'e' or piece.include? 'E' or piece.end_with? 'M'
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
		if (ahead = lookahead(2)) && (!ahead[1] || both?(ahead[1]))
			@source.read(1)
		elsif (ahead = lookahead(8)) && ahead[0, 7] == 'newline' && (!ahead[7] || both?(ahead[7]))
			@source.read(7) and "\n"
		elsif (ahead = lookahead(6)) && ahead[0, 5] == 'space' && (!ahead[5] || both?(ahead[5]))
			@source.read(5) and ' '
		elsif (ahead = lookahead(4)) && ahead[0, 3] == 'tab' && (!ahead[3] || both?(ahead[3]))
			@source.read(3) and "\t"
		elsif (ahead = lookahead(10)) && ahead[0, 9] == 'backspace' && (!ahead[9] || both?(ahead[9]))
			@source.read(9) and "\b"
		elsif (ahead = lookahead(9)) && ahead[0, 8] == 'formfeed' && (!ahead[8] || both?(ahead[8]))
			@source.read(8) and "\f"
		elsif (ahead = lookahead(7)) && ahead[0, 6] == 'return' && (!ahead[6] || both?(ahead[6]))
			@source.read(6) and "\r"
		elsif (ahead = lookahead(6)) && ahead[0, 5] =~ UNICODE_REGEX && (!ahead[5] || both?(ahead[5]))
			[@source.read(5)[1, 4].to_i(16)].pack('U')
		elsif (ahead = lookahead(5)) && ahead[0, 4] =~ OCTAL_REGEX && (!ahead[4] || both?(ahead[4]))
			@source.read(4)[1, 3].to_i(8).chr
		else
			raise SyntaxError, 'unknown character type'
		end
	end

	def read_keyword (ch)
		result = ''

		while (ch = @source.read(1)) && !keyword?(ch)
			result << ch
		end

		revert if ch

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

		result.gsub(STRING_REGEX) {|escape|
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
		string
	end

	def lookahead (length)
		result = @source.read(length)

		@source.seek(-result.length, IO::SEEK_CUR)

		result
	end

	def ignore (rev = true)
		while ignore?(ch = @source.read(1)); end

		rev ? revert : ch if ch
	end

	def revert (n = 1)
		@source.seek -n, IO::SEEK_CUR
	end

	def ignore? (ch)
		if ch == ' ' || ch == ',' || ch == "\n" || ch == "\r" || ch == "\t"
			true
		else
			false
		end
	end

	def both? (ch)
		if ch == ' ' || ch == ',' || ch == '"' || ch == '{' || ch == '}' || ch == '(' || ch == ')' || ch == '[' || ch == ']' || ch == '#' || ch == ':' || ch == "\n" || ch == "\r" || ch == "\t"
			true
		else
			false
		end
	end

	def keyword? (ch)
		if ch == ' ' || ch == ',' || ch == '"' || ch == '{' || ch == '}' || ch == '(' || ch == ')' || ch == '[' || ch == ']' || ch == '#' || ch == ':' || ch == "'" || ch == '^' || ch == '@' || ch == '`' || ch == '~' || ch == '\\' || ch == ';' || ch == "\n" || ch == "\r" || ch == "\t"
			true
		else
			false
		end
	end
end

end
