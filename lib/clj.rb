#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

require 'clj/types'
require 'clj/parser'

class Clojure
	def self.parse (*args)
		Clojure::Parser.new(*args).parse
	end

	def self.dump (what)
		raise ArgumentError, 'cannot convert the passed value to clojure' unless what.respond_to? :to_clj

		what.to_clj
	end
end
