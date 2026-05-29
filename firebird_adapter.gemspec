lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'firebird_adapter'
  spec.version       = '8.1.0'
  spec.authors       = ['Fábio Rodrigues']
  spec.email         = ['fabio.info@gmail.com']
  spec.summary       = 'ActiveRecord Firebird Adapter for Rails 8.'
  spec.homepage      = 'https://github.com/FabioMR/firebird_adapter'
  spec.license       = 'MIT'

  spec.files = Dir['lib/**/*']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.2'
  spec.add_dependency 'activerecord', '>= 8.0', '< 8.2'
  spec.add_dependency 'fb' #, '~> 0.9.3'

  spec.add_development_dependency 'bundler', '>= 2.4'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.13'
  spec.add_development_dependency 'database_cleaner', '~> 2.1'
  spec.add_development_dependency 'pry-meta', '~> 0.0.10'
end
