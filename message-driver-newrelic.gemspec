# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'message_driver/new_relic/version'

Gem::Specification.new do |spec|
  spec.name          = "message-driver-newrelic"
  spec.version       = MessageDriver::NewRelic::VERSION
  spec.authors       = ["Matt Campbell"]
  spec.email         = ["matt@soupmatt.com"]

  spec.summary       = %q{Add NewRelic instrumentation to MessageDriver}
  spec.homepage      = "https://github.com/message-driver/message-driver-newrelic"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  # spec.bindir        = "exe"
  # spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "newrelic_rpm", "~> 3.15"
  spec.add_dependency "message-driver", "~> 0.6.0"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.5"
end
