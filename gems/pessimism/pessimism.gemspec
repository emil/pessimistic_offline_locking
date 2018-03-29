# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'version'

Gem::Specification.new do |spec|
  spec.name          = "pessimism"
  spec.version       = ActiveRecord::Pessimism::VERSION
  spec.authors       = ["Emil Marcetta"]
  spec.email         = ["emarcetta@gmail.com"]
  spec.description   = %q{Pessimistic Offline Lock}
  spec.summary       = %q{Pessimistic Offline Lock}
  spec.homepage      = ""

  spec.files         = Dir["{lib}/**/*"] + ["LICENSE.txt", "Rakefile", "README.md"]
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.add_dependency "activerecord", "~> 5"
  spec.add_dependency "actionpack", "~> 5"
end
