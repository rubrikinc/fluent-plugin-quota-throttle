# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-quota-throttle"
  spec.version       = "0.0.1"
  spec.authors       = ["Athish Pranav D", "Dipendra Singh", "Rubrik Inc."]
  spec.email         = ["athish.pranav@rubrik.com", "Dipendra.Singh@rubrik.com"]
  spec.summary       = %q{Fluentd filter for throttling logs based on a configurable quotas.}
  spec.homepage      = "https://github.com/rubrikinc/fluent-plugin-quota-throttle"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "test-unit"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "mutex_m"

  spec.add_runtime_dependency "fluentd"
  spec.add_runtime_dependency "fluent-plugin-prometheus"
end
