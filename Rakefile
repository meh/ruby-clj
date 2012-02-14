#! /usr/bin/env ruby
require 'rake'

task :default => :test

task :test do
  Dir.chdir 'test'

  sh 'rspec clj_spec.rb --color --format doc'
end

task :bench do
	puts "Ruby: #{`test/bench/bench.rb`.strip}"
	puts "Python: #{`test/bench/bench.py`.strip}"
end
