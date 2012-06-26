require 'bundler'
Bundler::GemHelper.install_tasks

# test
require 'rake'
require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/test*.rb']
  t.verbose = true
end

# documentation
require 'yard'
require 'yard/rake/yardoc_task'
YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb', '-' , "README.rdoc","LICENSE"]
  t.options =  ["-r","README.rdoc"]
end

