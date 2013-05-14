# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rhack/version'

Gem::Specification.new do |spec|
  spec.name          = "rhack"
  spec.version       = RHACK::VERSION
  spec.authors       = ["Sergey Baev"]
  spec.email         = ["tinbka@gmail.com"]
  spec.description   = %q{RHACK is Ruby Http ACcess Kit: curl-based web-client framework created for developing web-scrapers/bots.\n\nFeatures:\nAsynchronous, still EventMachine independent\nFast as on simple queries as on high load\n3 levels of flexible configuration\nWeb-client abstraction for creating scrapers included}
  spec.summary       = %q{Curl-based web-client framework created for developing web-scrapers/bots}
  spec.homepage      = "https://github.com/tinbka/rhack"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.require_paths = ["lib"]
  
  spec.add_runtime_dependency "activesupport"
  spec.add_runtime_dependency "redis"
  spec.add_runtime_dependency "rmtools", ">= 1.3.3"
  spec.add_runtime_dependency "libxml-ruby"
  
  spec.extensions << 'ext/curb/extconf.rb'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end