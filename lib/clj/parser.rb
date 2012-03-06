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

	UNICODE_REGEX = /[0-9|a-f|A-F]{4}/
	OCTAL_REGEX   = /[0-3]?[0-7]?[0-7]/

	def initialize (source, options = {})
		@source  = source.is_a?(String) ? StringIO.new(source) : source
		@options = options

		@map_class    = options[:map_class]    || Clojure::Map
		@vector_class = options[:vector_class] || Clojure::Vector
		@list_class   = options[:list_class]   || Clojure::List
		@set_class    = options[:set_class]    || Clojure::Set
	end

	def parse
		result = read_next

		ignore(false)

		if @source.read(1)
			raise SyntaxError, 'there is some unconsumed input'
		end

		result
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
		else :symbol
		end
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
		check = @source.read(3)

		if check[0, 2] != 'il' || !both_separator?(check[2])
			revert(check.length) and read_symbol(ch)
		else
			nil
		end
	end

	def read_boolean (ch)
		if ch == 't'
			check = @source.read(4)

			if check[0, 3] != 'rue' || !both_separator?(check[3])
				revert(check.length) and read_symbol(ch)
			else
				true
			end
		else
			check = @source.read(5)

			if check[0, 4] != 'alse' || !both_separator?(check[4])
				revert(check.length) and read_symbol(ch)
			else
				false
			end
		end
	end

	def read_number (ch)
		piece = ch

		while (ch = @source.read(1)) && !both_separator?(ch)
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
		if (ahead = lookahead(2)) && both_separator?(ahead[1])
			@source.read(1)
		elsif (ahead = lookahead(8)) && ahead[0, 7] == 'newline' && both_separator?(ahead[7])
			@source.read(7) and "\n"
		elsif (ahead = lookahead(6)) && ahead[0, 5] == 'space' && both_separator?(ahead[5])
			@source.read(5) and ' '
		elsif (ahead = lookahead(4)) && ahead[0, 3] == 'tab' && both_separator?(ahead[3])
			@source.read(3) and "\t"
		elsif (ahead = lookahead(10)) && ahead[0, 9] == 'backspace' && both_separator?(ahead[9])
			@source.read(9) and "\b"
		elsif (ahead = lookahead(9)) && ahead[0, 8] == 'formfeed' && both_separator?(ahead[8])
			@source.read(8) and "\f"
		elsif (ahead = lookahead(7)) && ahead[0, 6] == 'return' && both_separator?(ahead[6])
			@source.read(6) and "\r"
		elsif (ahead = lookahead(6)) && ahead[0] == 'u' && ahead[1, 5] =~ UNICODE_REGEX && both_separator?(ahead[5])
			[@source.read(5)[1, 4].to_i(16)].pack('U')
		elsif (ahead = lookahead(5)) && ahead[0] == 'o' && matches = ahead[1, 3].match(OCTAL_REGEX)
			length = matches[0].length + 1

			if both_separator?(ahead[length])
				@source.read(length)[1, 3].to_i(8).chr
			end
		end or raise SyntaxError, 'unknown character type'
	end

	def read_symbol (ch)
		result = ch

		while (ch = @source.read(1)) && is_symbol?(ch)
			result << ch
		end

		revert if ch

		if result.include? '::'
			raise SyntaxError, 'symbols cannot have repeating :'
		end

		result.to_sym.symbol!
	end

	def read_keyword (ch)
		result = ''

		while (ch = @source.read(1)) && !keyword_separator?(ch)
			result << ch
		end

		revert if ch

		result.to_sym.keyword!
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

		Clojure.unescape(result)
	end

	def read_instant (ch)
		check = @source.read(3)

		if check.length != 3
			raise SyntaxError, 'unexpected EOF'
		elsif check != 'nst'
			raise SyntaxError, "expected inst, found i#{check}"
		end

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
			unless result.add? read_next
				raise SyntaxError, 'the set contains non unique values'
			end

			ignore
		end

		@source.read(1)

		result
	end

	def read_map (ch)
		result = @map_class.new

		ignore

		while lookahead(1) != '}'
			key = read_next
			ignore
			value = read_next
			ignore

			result[key] = value
		end

		@source.read(1)

		result
	end

	def lookahead (length)
		result = @source.read(length)

		if result
			@source.seek(-result.length, IO::SEEK_CUR)
		end

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
		ch == ' ' || ch == ',' || ch == "\n" || ch == "\r" || ch == "\t"
	end

	def is_symbol? (ch)
		(ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'z') || (ch >= 'A' || ch <= 'Z') || ch == '+' || ch == '!' || ch == '-' || ch == '_' || ch == '?' || ch == '.' || ch == ':' || ch == '/'
	end

	def both_separator? (ch)
		ch == nil || ch == ' ' || ch == ',' || ch == '"' || ch == '{' || ch == '}' || ch == '(' || ch == ')' || ch == '[' || ch == ']' || ch == '#' || ch == ':' || ch == "\n" || ch == "\r" || ch == "\t"
	end

	def keyword_separator? (ch)
		ch == nil || ch == ' ' || ch == ',' || ch == '"' || ch == '{' || ch == '}' || ch == '(' || ch == ')' || ch == '[' || ch == ']' || ch == '#' || ch == ':' || ch == "'" || ch == '^' || ch == '@' || ch == '`' || ch == '~' || ch == '\\' || ch == ';' || ch == "\n" || ch == "\r" || ch == "\t"
	end
end

end
