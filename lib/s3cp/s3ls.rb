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

require 'rubygems'
require 'extensions/kernel' if RUBY_VERSION =~ /1.8/
require 'right_aws'
require 'optparse'
require 'date'
require 'highline/import'

require 's3cp/utils'

# Parse arguments
options = {}
options[:date_format] = '%x %X'
options[:rows_per_page] = $terminal.output_rows if $stdout.isatty

op = OptionParser.new do |opts|
  opts.banner = "s3ls [path]"
  opts.separator ''

  opts.on("-l", "Long listing format") do
    options[:long_format] = true
  end

  opts.on("--date-format FORMAT", "Date format (see http://strfti.me/)") do |format|
    options[:date_format] = format
  end

  opts.on("--verbose", "Verbose mode") do
    options[:verbose] = true
  end

  opts.on("--rows ROWS", "Rows per page") do |rows|
    options[:rows_per_page] = rows.to_i
  end

  opts.on("--max-keys KEYS", "Maximum number of keys to display") do |keys|
    options[:max_keys] = keys.to_i
  end

  opts.on("--delimiter CHAR", "Display keys starting with given path prefix and up to delimiter character") do |delimiter|
    options[:delimiter] = delimiter
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts op
    exit
  end
end
op.parse!(ARGV)

unless ARGV.size > 0
  puts op
  exit
end

url = ARGV[0]

if options[:verbose]
  puts "URL: #{url}"
  puts "Options: #{options.inspect}"
end

@bucket, @key = S3CP.bucket_and_key(url)
fail "Your URL looks funny, doesn't it?" unless @bucket

if options[:verbose]
  puts "bucket #{@bucket}"
  puts "key #{@key}"
end

@s3 = S3CP.connect()

keys = 0
rows = 0

s3_options = Hash.new
s3_options[:prefix] = @key
s3_options["max-keys"] = options[:max_keys] if options[:max_keys] && !options[:delimiter]
s3_options[:delimiter] = options[:delimiter] if options[:delimiter]

@s3.interface.incrementally_list_bucket(@bucket, s3_options) do |page|
  entries = []
  if options[:delimiter]
    entries << { :key => page[:contents][0][:key] } if page[:contents].length > 0 && entries.length > 0
    page[:common_prefixes].each do |entry|
      entries << { :key => entry }
    end
    entries << { :key => nil }
  end
  entries += page[:contents]
  entries.each do |entry|
    key = entry[:key] ? "s3://#{@bucket}/#{entry[:key]}" : "---"
    if options[:long_format] && entry[:last_modified] && entry[:size]
      last_modified = DateTime.parse(entry[:last_modified])
      size = entry[:size]
      puts "#{last_modified.strftime(options[:date_format])} #{ "%12d" % size} #{key}"
    else
      puts key
    end
    rows += 1
    keys += 1
    if options[:max_keys] && keys >= options[:max_keys]
      exit
    end
    if options[:rows_per_page] && (rows % options[:rows_per_page] == 0)
      begin
        print "Continue? (Y/n) "
        response = STDIN.gets.chomp.downcase
      end until response == 'n' || response == 'y' || response == ''
      exit if response == 'n'
    end
  end
end

