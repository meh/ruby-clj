#--
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#++

require 'date'
require 'bigdecimal'

module Clojure
	def self.parse (*args)
		Clojure::Parser.new(*args).parse
	end

	def self.dump (what, options = {})
		raise ArgumentError, 'cannot convert the passed value to clojure' unless what.respond_to? :to_clj

		what.to_clj(options)
	end
end

require 'clj/types'

if RUBY_ENGINE == 'ruby' || RUBY_ENGINE == 'rbx'
	require 'clj/parser_ext'
else
	require 'clj/parser'
end
