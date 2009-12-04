require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "mzml"
    gem.summary = %Q{A non-validating mzML parser}
    gem.description = %Q{A non-validating mzML parser. MzML is a standard data format for representing mass spectrometry data.}
    gem.email = "angel@delagoya.com"
    gem.homepage = "http://github.com/delagoya/mzml"
    gem.authors = ["Angel Pizarro"]
    gem.add_development_dependency "rspec", ">= 1.2.9"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
    gem.add_dependency  "nokogiri", ">= 1.3.3"
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :spec => :check_dependencies

task :default => :spec

require 'yard'
YARD::Rake::YardocTask.new do |yardoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""
  yardoc.options = ["--title", "mzml #{version}", "-r", "README.rdoc"] 
  yardoc.files = ['README*','lib/**/*.rb']
end
