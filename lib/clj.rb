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
	def self.parse (*args)
		Clojure::Parser.new(*args).parse
	end

	def self.dump (what, options = {})
		raise ArgumentError, 'cannot convert the passed value to clojure' unless what.respond_to? :to_clj

		what.to_clj(options)
	end

	UNESCAPE_REGEX = %r((?:\\[\\bfnrt"/]|(?:\\u(?:[A-Fa-f\d]{4}))+|\\[\x20-\xff]))n

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

	def self.unescape (string)
		string.gsub(UNESCAPE_REGEX) {|escape|
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
end

require 'clj/types'

begin
	raise LoadError if RUBY_ENGINE == 'jruby' || ENV['CLJ_NO_C_EXT']

	require 'clj/parser_ext'
rescue LoadError
	require 'clj/parser'
end
