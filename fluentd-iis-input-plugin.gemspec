Gem::Specification.new do |gem|
  gem.name          = 'fluentd-iis-input-plugin'
  gem.summary       = 'fluentd input plugin for IIS Log Files'
  gem.description   = 'fluentd input plugin for W3C IIS Log Files'
  #gem.homepage      = 'TODO(talarico): Write me'
  gem.license       = 'Apache-2.0'
  gem.version       = '0.0.1'
  gem.authors       = ['Ian Talrico']
  gem.email         = ['talarico@google.com']

  gem.required_ruby_version = Gem::Requirement.new('>= 2.0')

  gem.files         = 'lib/fluent/plugin/*.rb'
  gem.test_files    = 'test/plugin/test*.rb'

  gem.add_runtime_dependency 'fluentd', '~> 0.10'

  gem.add_development_dependency 'rake', '~> 10.3'
  gem.add_development_dependency 'test-unit', '~> 3.0'
end
