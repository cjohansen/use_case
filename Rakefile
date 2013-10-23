require "rake/testtask"
require "ci/reporter/rake/minitest"

Rake::TestTask.new(:test) do |test|
  test.libs << "test"
  test.pattern = "test/**/*_test.rb"
end

task :default => :test
