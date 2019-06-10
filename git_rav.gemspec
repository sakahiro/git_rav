# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "git_rav/version"

Gem::Specification.new do |spec|
  spec.name          = "git_rav"
  spec.version       = GitRav::VERSION
  spec.authors       = ["sakahiro"]
  spec.email         = [""]

  spec.summary       = "Management git flow"
  spec.description   = "Management git flow"
  spec.homepage      = "https://github.com/sakahiro/git_rav"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "octokit"
  spec.add_dependency "thor"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
end
