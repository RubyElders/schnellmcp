Gem::Specification.new do |spec|
  spec.name          = "schnellmcp"
  spec.version       = "0.1.0"
  spec.authors       = ["Josef Šimánek"]
  spec.summary       = "Fast MCP server builder for Ruby using YARD annotations"
  spec.homepage      = "https://github.com/RubyElders/schnellmcp"
  spec.license       = "MIT"

  spec.files         = ["schnellmcp.rb", "README.md"]
  spec.require_paths = ["."]

  spec.required_ruby_version = ">= 3.0.0"

  spec.add_dependency "yard", "~> 0.9"
end
