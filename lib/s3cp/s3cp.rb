require 'rubygems'
require 'right_aws'
require 'optparse'
require 'date'
require 'highline/import'
require 'fileutils'

require 's3cp/utils'

# Parse arguments
options = {}
options[:verbose] = true if $stdout.isatty

op = OptionParser.new do |opts|
  opts.banner = "s3cp [path]"
  opts.separator ''

  opts.on("-r", "Recursive mode") do
    options[:recursive] = true
  end

  opts.on("--verbose", "Verbose mode") do
    options[:verbose] = true
  end

  opts.on("--debug", "Debug mode") do
    options[:debug] = true
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts op
    exit
  end
end
op.parse!(ARGV)

if ARGV.size < 2
  puts op
  exit
end

destination = ARGV.last
sources = ARGV[0..-2]

def s3?(url)
  S3CP.bucket_and_key(url)[0]
end

if options[:debug]
  puts "URL: #{url}"
  puts "Options: \n#{options.inspect}"
end

@bucket = $1
@prefix = $2

@s3 = S3CP.connect()

def direction(from, to)
  if s3?(from) && s3?(to)
    :s3_to_s3
  elsif !s3?(from) && s3?(to)
    :local_to_s3
  elsif s3?(from) && !s3?(to)
    :s3_to_local
  else
    :local_to_local
  end
end

def no_slash(path)
  path = path.match(/\/$/) ? path[0..-2] : path
  path.match(/^\//) ? path[1..-1] : path
end

def relative(base, path)
  no_slash(path[base.length..-1])
end

def copy(from, to, options)
  bucket_from, key_from = S3CP.bucket_and_key(from)
  bucket_to, key_to = S3CP.bucket_and_key(to)

  #puts "bucket_from #{bucket_from.inspect} key_from #{key_from.inspect}"
  #puts "bucket_to #{bucket_to.inspect} key_from #{key_to.inspect}"
  #puts "direction #{direction(from, to)}"

  case direction(from, to)
  when :s3_to_s3
    if options[:recursive]
      keys = []
      @s3.interface.incrementally_list_bucket(bucket_from, :prefix => key_from) do |page|
        page[:contents].each { |entry| keys << entry[:key] }
      end
      keys.each do |key|
        dest = no_slash(key_to) + '/' + relative(key_from, key)
        puts "Copy s3://#{bucket_from}/#{key} to s3://#{bucket_to}/#{dest}"
        @s3.interface.copy(bucket_from, key, bucket_to, dest)
      end
    else
      puts "Copy s3://#{bucket_from}/#{key_from} to s3://#{bucket_to}/#{key_to}"
      @s3.interface.copy(bucket_from, key_from, bucket_to, key_to)
    end
  when :local_to_s3
    if options[:recursive]
      files = Dir[from + "/**/*"]
      files.each do |f|
        f = File.expand_path(f)
        key = no_slash(key_to) + '/' + relative(from, f)
        puts "Copy #{f} to s3://#{bucket_to}/#{key}"
        @s3.interface.put(bucket_to, key,  File.open(f))
      end
    else
      f = File.expand_path(from)
      puts "Copy #{f} to s3://#{bucket_to}/#{key_to}"
      f = File.open(f)
      begin
        @s3.interface.put(bucket_to, key_to, f)
      ensure
        f.close()
      end
    end
  when :s3_to_local
    if options[:recursive]
      keys = []
      @s3.interface.incrementally_list_bucket(bucket_from, :prefix => key_from) do |page|
        page[:contents].each { |entry| keys << entry[:key] }
      end
      keys.each do |key|
        dest = File.expand_path(to) + '/' + relative(key_from, key)
        dest = File.join(dest, File.basename(key)) if File.directory?(dest)
        puts "Copy s3://#{bucket_from}/#{key} to #{dest}"
        f = File.new(dest, File::CREAT|File::RDWR)
        begin
          @s3.interface.get(bucket_from, key) do |chunk|
            f.write(chunk)
          end
        ensure
          f.close()
        end
      end
    else
      dest = File.expand_path(to)
      dest = File.join(dest, File.basename(key_from)) if File.directory?(dest)
      puts "Copy s3://#{bucket_from}/#{key_from} to #{dest}"
      f = File.new(dest, File::CREAT|File::RDWR)
      begin
        @s3.interface.get(bucket_from, key_from) do |chunk|
          f.write(chunk)
        end
      ensure
        f.close()
      end
    end
  when :local_to_local
    if options[:recursive]
      FileUtils.cp_r from, to
    else
      FileUtils.cp from, to
    end
  end
end

sources.each do |source|
  copy(source, destination, options)
end

