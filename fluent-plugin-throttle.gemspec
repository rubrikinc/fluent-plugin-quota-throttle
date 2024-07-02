# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-quota-throttle"
  spec.version       = "0.0.1"
  spec.authors       = ["Athish"]
  spec.email         = ["athish.pranav@rubrik.com"]
  spec.summary       = %q{Fluentd filter for throttling logs based on a configurable quota for each group.}
  spec.homepage      = "https://github.com/rubrikinc/fluent-plugin-quota-throttle"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.5"
  spec.add_development_dependency "rake", "~> 13.2"
  spec.add_development_dependency "webmock", "~> 3.3"
  spec.add_development_dependency "test-unit", "~> 3.2"
  spec.add_development_dependency "appraisal", "~> 2.2"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency "maxitest"
  spec.add_development_dependency "single_cov"

  spec.add_dependency "prometheus-client", '~> 4.2'
  spec.add_dependency "fluentd", "~> 1.1"
  spec.add_dependency "fluent-plugin-prometheus", "~> 2.1"
end
