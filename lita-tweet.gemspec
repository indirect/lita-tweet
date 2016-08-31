Gem::Specification.new do |spec|
  spec.name          = "lita-tweet"
  spec.version       = "0.4.0"
  spec.authors       = ["Andre Arko"]
  spec.email         = ["andre@arko.net"]
  spec.description   = "Tweeting for Lita"
  spec.summary       = "Allows the Lita chat bot to tweet on command"
  spec.homepage      = "https://github.com/indirect/lita-tweet"
  spec.license       = "MIT"
  spec.metadata      = { "lita_plugin_type" => "handler" }

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "lita", ">= 4.7"
  spec.add_runtime_dependency "twitter", "~> 5.16"
  spec.add_runtime_dependency "oauth", "~> 0.5.1"

  spec.add_development_dependency "bundler", "~> 1.12"
end
