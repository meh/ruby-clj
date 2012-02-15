#! /usr/bin/env ruby
require 'rubygems'
require 'clj'

s = "[1 2 3 true false nil {:a 21.3 :b 43.2} \"Hello\"]"

t1 = Time.now()

0.upto 10000 do
  Clojure.parse(s)
end

puts Time.now()-t1
