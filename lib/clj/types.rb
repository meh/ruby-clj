#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

module Clojure
	module Metadata
		def metadata
			@metadata ||= Clojure::Map.new
		end

		def metadata= (value)
			metadata.merge! case value
				when Hash   then value
				when Symbol then { value => true }
				when String then { :tag => value }
				else raise ArgumentError, 'the passed value is not suitable as metadata'
			end
		end

		def metadata_to_clj (options = {})
			return '' unless options[:metadata] != false && @metadata && !@metadata.empty?

			'^' + if @metadata.length == 1
				piece = @metadata.first

				if piece.first.is_a?(Symbol) && piece.last == true
					piece.first.to_clj(options)
				elsif piece.first == :tag && piece.last.is_a?(String)
					piece.last.to_clj(options)
				else
					@metadata.to_clj(options)
				end
			else
				@metadata.to_clj(options)
			end + ' '
		end
	end

	class Map < Hash
		include Clojure::Metadata

		def to_clj (options = {})
			metadata_to_clj(options) + '{' + map { |k, v| k.to_clj(options) + ' ' + v.to_clj(options) }.join(' ') + '}'
		end
	end

	class Vector < Array
		include Clojure::Metadata

		def to_clj (options = {})
			metadata_to_clj(options) + '[' + map { |o| o.to_clj(options) }.join(' ') + ']'
		end
	end

	class List < Array
		include Clojure::Metadata

		def to_clj (options = {})
			metadata_to_clj(options) + '(' + map { |o| o.to_clj(options) }.join(' ') + ')'
		end
	end

	class Set < Array
		include Clojure::Metadata

		def to_clj (options = {})
			metadata_to_clj(options) + '#{' + uniq.map { |o| o.to_clj(options) }.join(' ') + '}'
		end
	end
end

[Numeric, TrueClass, FalseClass, NilClass].each {|klass|
	klass.instance_eval {
		define_method :to_clj do |*|
			inspect
		end
	}
}

class Symbol
	def to_clj (options = {})
		result = inspect

		unless result =~ /:([^(\[{'^@`~\"\\,\s;)\]}]+)/
			raise ArgumentError, "#{result} cannot be transformed into clojure"
		end

		result
	end
end

class String
	def to_clj (options = {})
		result = if respond_to? :encode
			encode('UTF-16be').inspect
		else
			inspect
		end
		
		result.gsub!(/(^|[^\\])\\e/, '\1\u001b')
		result.gsub!(/(^|[^\\])\\a/, '\1\u0003')

		result
	end
end

class Rational
	def to_clj (options = {})
		to_s
	end
end

class Regexp
	def to_clj (options = {})
		'#"' + inspect[1 .. -2] + '"'
	end
end

class DateTime
	def to_clj (options = {})
		options[:alpha] ? '#inst "' + rfc3339 + '"' : to_time.to_i.to_s
	end
end

class Date
	def to_clj (options = {})
		to_datetime.to_clj(options)
	end
end

class Time
	def to_clj (options = {})
		to_datetime.to_clj(options)
	end
end

class Bignum < Integer
	def to_clj (options = {})
		to_s + 'N'
	end
end

class BigDecimal < Numeric
	def to_clj (options = {})
		to_s('F') + 'M'
	end
end

class Array
	def to_clj (options = {})
		to_vector.to_clj(options)
	end

	def to_set
		Clojure::Set.new(self)
	end

	def to_vector
		Clojure::Vector.new(self)
	end

	def to_list
		Clojure::List.new(self)
	end
end

class Hash
	def to_clj (options = {})
		to_map.to_clj(options)
	end

	def to_map
		Clojure::Map[self]
	end
end
