# frozen_string_literal: true

require_relative "lib/synotion/version"

Gem::Specification.new do |spec|
  spec.name = "synotion"
  spec.version = Synotion::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "Sync Markdown files to Notion pages"
  spec.description = "A Ruby gem to synchronize Markdown files to Notion pages with support for multiple update modes (create, append, replace, upsert)"
  spec.homepage = "https://github.com/ydah/synotion"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ydah/synotion"
  spec.metadata["changelog_uri"] = "https://github.com/ydah/synotion/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "notion-ruby-client", "~> 1.2"
  spec.add_dependency "redcarpet", "~> 3.6"
  spec.add_dependency "front_matter_parser", "~> 1.0"
  spec.add_dependency "thor", "~> 1.3"
end
