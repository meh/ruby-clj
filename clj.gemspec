Gem::Specification.new {|s|
	s.name         = 'clj'
	s.version      = '0.0.4.4'
	s.author       = 'meh.'
	s.email        = 'meh@paranoici.org'
	s.homepage     = 'http://github.com/meh/ruby-clj'
	s.platform     = Gem::Platform::RUBY
	s.summary      = 'Like json, but with clojure sexps.'
	s.files        = Dir.glob('lib/**/*.rb')
	s.require_path = 'lib'

	s.add_development_dependency 'rake'
	s.add_development_dependency 'rspec'
}
