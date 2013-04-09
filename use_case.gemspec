require "./lib/use_case/version"

Gem::Specification.new do |s|
  s.name = "use_case"
  s.version = UseCase::VERSION
  s.author = "Christian Johansen"
  s.email = "christian@gitorious.com"
  s.homepage = "http://gitorious.org/gitorious/use_case"
  s.summary = s.description = ""

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files test`.split("\n")
  s.require_path = "lib"

  s.add_development_dependency "minitest", "~> 4"
  s.add_development_dependency "rake"
end
