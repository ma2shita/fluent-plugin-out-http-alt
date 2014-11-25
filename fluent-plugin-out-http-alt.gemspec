# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-out-http-alt"
  gem.version       = "0.0.1"
  gem.authors       = ["Kohei MATSUSHITA"]
  gem.email         = ["ma2shita+git@ma2shita.jp"]
  gem.summary       = %q{A generic Fluentd output plugin to send logs to an HTTP endpoint w/ bufferd}
  gem.description   = gem.summary
  gem.homepage      = "https://github.com/ma2shita/fluent-plugin-out-http-alt"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.required_ruby_version = "1.9.3"

  gem.add_runtime_dependency "yajl-ruby", "~> 1.0"
  gem.add_runtime_dependency "fluentd", "~> 0.10.0"
  gem.add_development_dependency "bundler"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "pry-debugger"
end
