Gem::Specification.new {|s|
	s.name         = 'clj'
	s.version      = '0.0.6'
	s.author       = 'meh.'
	s.email        = 'meh@paranoici.org'
	s.homepage     = 'http://github.com/meh/ruby-clj'
	s.platform     = Gem::Platform::RUBY
	s.summary      = 'Like json, but with clojure sexps.'
	s.files        = Dir['ext/**/*.{c,h,rb}'] + Dir['lib/**/*.rb']
	s.extensions   = 'ext/clj/extconf.rb'

	s.add_development_dependency 'rake'
	s.add_development_dependency 'rspec'
}
