#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

[String, Symbol, Numeric, TrueClass, FalseClass, NilClass].each {|klass|
	klass.instance_eval {
		alias_method :to_clj, :inspect
	}
}

class Rational
	alias to_clj to_s
end

class Regexp
	def to_clj
		'#"' + inspect[1 .. -2] + '"'
	end
end

class Date
	def to_clj
		to_time.to_clj
	end
end

class Time
	def to_clj
		to_i.to_s
	end
end

if defined? BigDecimal
	class BigDecimal
		def to_clj
			inspect + 'M'
		end
	end
end

class Array
	def to_clj
		'[' + map { |o| o.to_clj }.join(' ') + ']'
	end
end

class Hash
	def to_clj
		'{' + map { |k, v| k.to_clj + ' ' + v.to_clj }.join(' ') + '}'
	end
end
