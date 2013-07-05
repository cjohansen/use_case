require "rake/testtask"
require "ci/reporter/rake/minitest"

Rake::TestTask.new(:test) do |test|
  test.libs << "test"
  test.pattern = "test/**/*_test.rb"
end

if RUBY_VERSION < "1.9"
  require "rcov/rcovtask"
  Rcov::RcovTask.new do |t|
    t.libs << "test"
    t.test_files = FileList["test/**/*_test.rb"]
    t.rcov_opts += %w{--exclude gems}
  end
end

task :default => :test
