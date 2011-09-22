lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require "s3cp/version"

Gem::Specification.new do |s|
  s.name        = "s3cp"
  s.version     = S3CP::VERSION
  s.platform    = Gem::Platform::RUBY

  s.authors     = ["Alex Boisvert"]
  s.email       = ["alex.boisvert@gmail.com"]

  s.summary     = "Amazon S3 tools to, e.g., list, copy, delete S3 files"

  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency("extensions", ["~> 0.6"])
  s.add_dependency("highline", ["~> 1.5.1"])
  s.add_dependency("right_aws", ["~> 2.1.0"])
  s.add_dependency("right_http_connection", ["~> 1.3.0"])

  s.add_development_dependency("rspec", ["~> 2.5.0"])
  s.add_development_dependency("rake", ["~> 0.8.7"])

  s.files        = Dir.glob("lib/**/*") +
                   %w{History.txt README.md} +
                   Dir.glob("bin/*")

  s.executables << 's3ls'
  s.executables << 's3cp'
  s.executables << 's3cat'
  s.executables << 's3mod'

  s.extra_rdoc_files = ['README.md', 'History.txt']

  s.require_path = 'lib'
end

