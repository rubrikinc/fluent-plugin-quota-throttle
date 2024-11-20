# coding: utf-8
lib = File.expand_path('./lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-dedupe-with-redis"
  spec.version       = "1.0.0"
  spec.authors       = ["Akshit Mehta"]
  spec.email         = ["akshit.mehta@rubrik.com", "dipendra.singh@rubrik.com", "himanshu.soni@rubrik.com"]
  spec.summary       = %q{Fluentd filter for throttling logs based on a configurable key.}
  spec.homepage      = "https://github.com/rubrikinc/fluent-plugin-dedupe_with_redis"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files`.split($/) # Dir.glob("lib/**/*.rb") + Dir.glob("test/**/*") + ["LICENSE", "README.md", "fluent-plugin-dedupe-with-redis.gemspec"]
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "test-unit", "~> 3.6"
  spec.add_development_dependency "mocha", "~> 2.5.0"
  spec.add_development_dependency "minitest", "~> 5.14.0"
  spec.add_development_dependency "single_cov", "~> 1.11.0"
  spec.add_development_dependency "base64" , "~> 0.2"

  spec.add_runtime_dependency "fluentd", "~> 1.9"
  spec.add_runtime_dependency "redis", "~> 4.8.1"
  spec.add_runtime_dependency "fluent-plugin-prometheus", "~> 2.1.0"
end

