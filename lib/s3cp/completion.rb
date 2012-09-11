# Copyright (C) 2010-2012 Alex Boisvert and Bizo Inc. / All rights reserved.
#
# Licensed to the Apache Software Foundation (ASF) under one or more contributor
# license agreements.  See the NOTICE file  distributed with this work for
# additional information regarding copyright ownership.  The ASF licenses this
# file to you under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License.  You may obtain a copy of
# the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.

require 's3cp/utils'
require 'tempfile'

cmd_line = ENV['COMP_LINE']
position = ENV['COMP_POINT'].to_i

url = begin
  start = position
  start -= 1 while start >= 1 && cmd_line[start-1].chr != ' '
  cmd_line[start..position-1].gsub("\"", "")
end

cmd = ARGV[0]
arg1 = ARGV[1]
arg2  = ARGV[2]

DEBUG = true

S3CP.load_config()

@s3 = S3CP.connect()

if DEBUG
  @debug = File.open("/tmp/s3cp_complete", "wb")
end

def debug(str)
  @debug.puts(str) if @debug
end

debug "url #{url}"

debug "arg1 #{arg1.inspect}"
debug "arg2 #{arg2.inspect}"

delimiter = ENV["S3CP_DELIMITER"] || "/"
debug "delimiter #{delimiter}"

excludes = (ENV["S3CP_EXCLUDES"] || "_$folder$").split(",")

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
  keys << keys[0] + " " if keys.size == 1 && @dirs_only
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
  dir_options[:delimiter] = delimiter
  begin
    result = []
    @s3.buckets[bucket_from].objects.with_prefix(prefix).as_tree(:delimier => options[:delimiter], :append => false).children.each do |entry|
      result << entry.key
    end
  rescue => e
    debug "exception #{e}"
    result = []
  end

  excludes.each do |exclude|
    result.reject! { |key| key.match(Regexp.escape(exclude)) }
  end

  debug "result1 #{result.inspect}"

  # there may be longer matches
  if (result.size == 0) || (result.size == 1)
    prefix = result[0] if result.size == 1
    s3_options = Hash.new
    s3_options[:limit] = 1000
    short_keys = Hash.new
    all_keys = []
    begin
      @s3.buckets[bucket].objects.with_prefix(prefix).each(s3_options) do |entry|
        key = entry.key
        pos = prefix.length-1
        pos += 1 while pos+1 < key.length && key[pos+1].chr == delimiter
        short_key = key[0..pos]
        short_keys[short_key] = key
        all_keys << key
      end
    rescue => e
      debug "exception #{e}"
      result = []
    end
    result = @dirs_only ? short_keys.keys.sort : all_keys
    debug "result2 #{result.inspect}"
  end

  excludes.each do |exclude|
    result.reject! { |key| key.match(Regexp.escape(exclude)) }
  end

  debug "final #{result.inspect}"

  print_keys(bucket, result)
else
  # complete bucket name
  bucket ||= url
  begin
    bucket_names = @s3.buckets.to_a.map(&:name)
    matching = bucket_names.select { |b| b =~ /^#{bucket}/ }
    print_buckets(matching)
  rescue => e
    debug "exception #{e}"
    result = []
  end
end

@debug.close() if DEBUG

