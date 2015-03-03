require "bundler"
Bundler.setup

require "rake"
require "rake/rdoctask"
require "rspec"
require "rspec/core/rake_task"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "s3cp/version"

GEM = "s3cp-#{S3CP::VERSION}.gem"

task :gem => :build
task :build do
  sh "gem build s3cp.gemspec"
end

task :install => :build do
  sh "sudo gem install #{GEM}"
end

task :tag do
  tag ="s3cp-#{S3CP::VERSION}"
  puts "Tagging #{tag}..."
  sh "git tag -a #{tag} -m 'Tagging #{tag}'"
  puts "Pushing to tags to remote..."
  sh "git push origin master"
  sh "git push --tags"
end

task :upload => [:gem] do
  cmd =
  sh "s3cp #{GEM} com-bizo-repository-v2:bizo.com/s3cp-ruby/#{GEM} "
end

task :push => [:gem] do
  sh "gem push #{GEM}"
end

task :release => [:build, :tag, :upload, :push]

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

