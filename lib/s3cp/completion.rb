require 'rubygems'
require 'extensions/kernel' if RUBY_VERSION =~ /1.8/
require 'right_aws'
require 'optparse'
require 'date'
require 'highline/import'
require 'tempfile'

require 's3cp/utils'

cmd_line = ENV['COMP_LINE']
position = ENV['COMP_POINT'].to_i

url = begin
  start = position
  start -= 1 while start >= 1 && cmd_line[start-1].chr != ' '
  cmd_line[start..position-1]
end

cmd = ARGV[0]
arg1 = ARGV[1]
arg2  = ARGV[2]

DEBUG = true

@s3 = S3CP.connect()

if DEBUG
  @debug = File.open("/tmp/s3cp_complete", "wb")
end

def debug(str)
  @debug.puts(str) if @debug
end

debug "url #{url}"

delimiter = ENV["S3CP_DELIMITER"] || "/"
debug "delimiter #{delimiter}"

bucket, prefix = S3CP.bucket_and_key(url)
if bucket == "s3"
  bucket = ""
  prefix = nil
end

debug "bucket #{bucket.inspect} prefix #{prefix.inspect}"

@legacy_format = (url =~ /\:\//) ? false : true
debug "legacy_format #{@legacy_format} "

recursive = cmd_line.split(" ").include?("-r")
debug "recursive #{recursive}"

@dirs_only = (cmd =~ /s3dir$/) || (cmd =~ /s3cp$/ && recursive) || (cmd =~ /s3rm$/ && recursive)
debug "dirs_only #{@dirs_only}"

def print_keys(bucket, keys)
  keys.each do |key|
    if @legacy_format
      debug key
      puts key
    else
      debug "//#{bucket}/#{key}"
      puts "//#{bucket}/#{key}"
    end
  end
end

def print_buckets(buckets)
  buckets = buckets.map { |b| @legacy_format ? b + ":" : b + "/"  }
  buckets << buckets[0] + " " if buckets.size == 1
  buckets.each do |bucket|
    if @legacy_format
      debug bucket
      puts bucket
    else
      debug "//#{bucket}"
      puts "//#{bucket}"
    end
  end
end

if (prefix && prefix.length > 0) || (url =~ /s3\:\/\/[^\/]+\//) || (url =~ /\:$/)
  # complete s3 key name
  bucket, prefix = S3CP.bucket_and_key(url)
  fail "Your URL looks funny, doesn't it?" unless bucket

  result = nil

  # try directory first
  dir_options = Hash.new
  dir_options[:prefix] = prefix
  dir_options[:delimiter] = delimiter
  begin
    @s3.interface.incrementally_list_bucket(bucket, dir_options) do |page|
      entries = page[:common_prefixes]
      entries << page[:contents][0][:key] if page[:contents].length > 0 && entries.length > 0
      result = entries
    end
  rescue => e
    debug "exception #{e}"
    result = []
  end

  debug "result1 #{result.inspect}"

  # there may be longer matches
  if (result.size == 0) || (result.size == 1)
    prefix = result[0] if result.size == 1
    file_options = Hash.new
    file_options[:prefix] = prefix
    file_options["max-keys"] = 100
    short_keys = Hash.new
    all_keys = []
    begin
      @s3.interface.incrementally_list_bucket(bucket, file_options) do |page|
        entries = page[:contents]
        entries.each do |entry|
          key = entry[:key]
          pos = prefix.length-1
          pos += 1 while pos+1 < key.length && key[pos+1].chr == delimiter
          short_key = key[0..pos]
          short_keys[short_key] = key
          all_keys << key
        end
      end
    rescue => e
      debug "exception #{e}"
      result = []
    end
    result = @dirs_only ? short_keys.keys.sort : all_keys
    debug "result2 #{result.inspect}"
  end

  debug "final #{result.inspect}"

  print_keys(bucket, result)
else
  # complete bucket name
  bucket ||= url
  begin
    buckets = @s3.interface.list_all_my_buckets()
    bucket_names = buckets.map { |b| b[:name] }
    matching = bucket_names.select { |b| b =~ /^#{bucket}/ }
    print_buckets(matching)
  rescue => e
    debug "exception #{e}"
    result = []
  end
end

@debug.close() if DEBUG

