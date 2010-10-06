# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{typho-twitter}
  s.version = "0.0.12"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["shock"]
  s.date = %q{2010-10-06}
  s.description = %q{A Twitter client for performing a batch of Twitter calls in parallel.}
  s.email = %q{billdoughty@capitalthought.com}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "lib/typho-twitter.rb",
     "lib/typho-twitter/typho-twitter.rb",
     "spec/spec.opts",
     "spec/spec_helper.rb",
     "test/typho-twitter-test.rb",
     "typho-twitter.gemspec"
  ]
  s.homepage = %q{http://github.com/capitalthought/typho-twitter}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Parallel twitter client using Typhoeus.}
  s.test_files = [
    "spec/spec_helper.rb",
     "test/typho-twitter-test.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rspec>, [">= 1.2.9"])
      s.add_runtime_dependency(%q<wdd-ruby-ext>, [">= 0.0.8"])
      s.add_runtime_dependency(%q<typhoeus>, [">= 0.1.24"])
    else
      s.add_dependency(%q<rspec>, [">= 1.2.9"])
      s.add_dependency(%q<wdd-ruby-ext>, [">= 0.0.8"])
      s.add_dependency(%q<typhoeus>, [">= 0.1.24"])
    end
  else
    s.add_dependency(%q<rspec>, [">= 1.2.9"])
    s.add_dependency(%q<wdd-ruby-ext>, [">= 0.0.8"])
    s.add_dependency(%q<typhoeus>, [">= 0.1.24"])
  end
end

