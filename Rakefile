require "bundler"
Bundler.setup

require "rake"
require "rake/rdoctask"
require "rspec"
require "rspec/core/rake_task"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "s3cp/version"

task :gem => :build
task :build do
  system "gem build s3cp.gemspec"
end

task :install => :build do
  system "sudo gem install s3cp-#{S3CP::VERSION}.gem"
end

task :tag do
  tag ="s3cp-#{S3CP::VERSION}"
  puts "Tagging #{tag}..."
  system "git tag -a #{tag} -m 'Tagging #{tag}'"
  puts "Pushing to tags to remote..."
  system "git push --tags"
end

task :upload => [:gem] do
  cmd = "s3cmd put com-bizo-repository:bizo.com/s3cp-ruby/s3cp-#{S3CP::VERSION}.gem s3cp-#{S3CP::VERSION}.gem"
  sh cmd
end

task :release => [:build, :upload, :tag]

=begin
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = "spec/**/*_spec.rb"
end

RSpec::Core::RakeTask.new('spec:progress') do |spec|
  spec.rspec_opts = %w(--format progress)
  spec.pattern = "spec/**/*_spec.rb"
end
=end

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.title = "s3cp #{S3CP::VERSION}"
  rdoc.rdoc_files.include("README*")
  rdoc.rdoc_files.include("lib/**/*.rb")
end

task :default => :gem

