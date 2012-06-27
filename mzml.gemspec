# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "mzml/version"

Gem::Specification.new do |s|
  s.name        = "mzml"
  s.version     = MzML::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Angel Pizarro"]
  s.email       = ["angel@upenn.edu"]
  s.summary = %q{A non-validating mzML parser}
  s.description = %q{A non-validating mzML parser. MzML is a standard data format for representing mass spectrometry data.}
  s.homepage    = "http://github.com/delagoya/mzml"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ["lib"]
  s.add_dependency("nokogiri", ["~> 1.5"])
  s.add_development_dependency "rake"
  s.add_development_dependency "yard"
end
