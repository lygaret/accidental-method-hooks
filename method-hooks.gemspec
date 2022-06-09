require "yaml"

header = YAML.safe_load_file("readme.md")
Gem::Specification.new do |spec|
  spec.name          = header["name"]
  spec.version       = header["version"]
  spec.authors       = ["Jon Raphaelson"]
  spec.email         = ["jon@accidental.cc"]

  spec.summary       = header["summary"]
  spec.license       = "MIT"

  spec.files         = Dir.glob("**/*.rb", base: __dir__)
  spec.require_paths = ["."]
end
