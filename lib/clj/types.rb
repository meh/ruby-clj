#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

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
		if options[:alpha]
			'#inst "' + rfc3339 + '"'
		else
			to_time.to_i.to_s
		end
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
		'[' + map { |o| o.to_clj(options) }.join(' ') + ']'
	end
end

class Hash
	def to_clj (options = {})
		'{' + map { |k, v| k.to_clj(options) + ' ' + v.to_clj(options) }.join(' ') + '}'
	end
end
