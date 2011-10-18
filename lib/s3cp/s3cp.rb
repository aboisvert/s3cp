require 'rubygems'
require 'extensions/kernel' if RUBY_VERSION =~ /1.8/
require 'right_aws'
require 'optparse'
require 'date'
require 'highline/import'
require 'fileutils'

require 's3cp/utils'

# Parse arguments
options = {}
options[:verbose] = $stdout.isatty ? true : false
options[:headers] = []

op = OptionParser.new do |opts|
  opts.banner = <<-BANNER
    s3cp supports 4 coyping use cases:
      1. Copy from local machine to S3
      2. Copy from S3 to local machine
      3. Copy from S3 to S3
      4. Copy from local machine to another path on local machine (for completeness)

    Local to S3:
      s3cp LOCAL_PATH S3_PATH

    S3 to Local:
      s3cp S3_PATH LOCAL_PATH

    S3 to S3:
      s3cp S3_PATH S3_PATH2

    Local to Local:
      s3cp LOCAL_PATH LOCAL_PATH2

  BANNER
  opts.separator ''

  opts.on('--headers \'Header1: Header1Value\',\'Header2: Header2Value\'', Array, "Headers to set on the item in S3.  This can include http headers like \'Content-Type: image/jpg\' or AMZ headers like: \'x-amz-acl: public-read\'" ) do |h|
    options[:headers] = h
  end

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

if options[:verbose]
  @verbose = true
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

def log(msg)
  puts msg if @verbose
end

def headers_array_to_hash(header_array)
  headers = {}
  header_array.each do |header|
    header_parts = header.split(": ", 2)
    if header_parts.size == 2
      headers[header_parts[0].downcase] = header_parts[1]  # RightAWS gem expect lowercase header names :(
    else
      log("Header ignored because of error splitting [#{header}].  Expected colon delimiter; e.g. Header: Value")
    end
  end
  headers
end
@headers = headers_array_to_hash(options[:headers])

def with_headers(msg)
  unless @headers.empty?
    msg += " with headers:"
    msg += @headers.collect{|k,v| "'#{k}: #{v}'"}.join(", ")
  end
  msg
end

def s3_to_s3(bucket_from, key, bucket_to, dest)
  log(with_headers("Copy s3://#{bucket_from}/#{key} to s3://#{bucket_to}/#{dest}"))
  if @headers.empty?
    @s3.interface.copy(bucket_from, key, bucket_to, dest)
  else
    @s3.interface.copy(bucket_from, key, bucket_to, dest, :copy, @headers)
  end
end

def local_to_s3(bucket_to, key, file)
  log(with_headers("Copy #{file} to s3://#{bucket_to}/#{key}"))
  f = File.open(file)
  begin
    @s3.interface.put(bucket_to, key, f, @headers)
  ensure
    f.close()
  end
end

def s3_to_local(bucket_from, key_from, dest)
  log("Copy s3://#{bucket_from}/#{key_from} to #{dest}")
  f = File.new(dest, File::CREAT|File::RDWR)
  begin
    @s3.interface.get(bucket_from, key_from) do |chunk|
      f.write(chunk)
    end
  ensure
    f.close()
  end
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
        s3_to_s3(bucket_from, key, bucket_to, dest)
      end
    else
      s3_to_s3(bucket_from, key_from, bucket_to, key_to)
    end
  when :local_to_s3
    if options[:recursive]
      files = Dir[from + "/**/*"]
      files.each do |f|
        f = File.expand_path(f)
        key = no_slash(key_to) + '/' + relative(from, f)
        local_to_s3(bucket_to, key, f)
      end
    else
      local_to_s3(bucket_to, key_to, File.expand_path(from))
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
        dir = File.dirname(dest)
        FileUtils.mkdir_p dir unless File.exist? dir
        fail "Destination path is not a directory: #{dir}" unless File.directory?(dir)
        s3_to_local(bucket_from, key, dest)
      end
    else
      dest = File.expand_path(to)
      dest = File.join(dest, File.basename(key_from)) if File.directory?(dest)
      s3_to_local(bucket_from, key_from, dest)
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

