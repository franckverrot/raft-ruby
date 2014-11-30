# coding: utf-8
$:<< 'lib'

Gem::Specification.new do |spec|
  spec.name          = "raft-ruby"
  spec.version       = "0.0.1"
  spec.authors       = ["Franck Verrot"]
  spec.email         = ["franck@verrot.fr"]
  spec.summary       = %q{Raft implementation in Ruby}
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/franckverrot/raft-ruby"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "minitest"

  spec.cert_chain  = ['certs/franckverrot.pem']
  spec.signing_key = File.expand_path(ENV['RUBYGEMS_CERT_PATH']) if $0 =~ /gem\z/
end
