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

# Parse arguments
options = {}
options[:date_format] = ENV['S3CP_DATE_FORMAT'] || '%x %X'
options[:rows_per_page] = ($terminal.output_rows - 1) if $stdout.isatty
options[:precision] = 0

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

  opts.on("--unit UNIT", "Force unit to use for file size display: #{S3CP::UNITS.join(', ')}.") do |unit|
    options[:unit] = unit
  end

  opts.on("--precision PRECISION", "Precision used to display sizes, e.g. 3 => 0.123GB. (default 0)") do |precision|
    options[:precision] = precision.to_i
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

S3CP.load_config()

@s3 = S3CP.connect()

keys = 0
rows = 0
directories = true

begin
  display = lambda do |entry|
    # add '---' separator line between directories and files
    if options[:delimiter] && directories && entry.is_a?(AWS::S3::Tree::LeafNode)
      directories = false
      puts "---"
    end

    key = "s3://#{@bucket}/#{entry.respond_to?(:key) ? entry.key : entry.prefix}"
    if options[:long_format] && entry.last_modified && entry.content_length
      size = entry.content_length
      size = S3CP.format_filesize(size, :unit => options[:unit], :precision => options[:precision])
      size = ("%#{7 + options[:precision]}s " % size)
      puts "#{entry.last_modified.strftime(options[:date_format])} #{size} #{key}"
    else
      puts key
    end
    rows += 1
    keys += 1
    response = ''
    if options[:rows_per_page] && (rows % options[:rows_per_page] == 0)
      begin
        print "Continue? (Y/n) "
        response = STDIN.gets.chomp.downcase
      end until response == 'n' || response == 'y' || response == ''
    end
    (response == 'n')
  end

  if options[:delimiter]
    @s3.buckets[@bucket].objects.with_prefix(@key).as_tree(:delimier => options[:delimiter], :append => false).children.each do |entry|
      break if display.call(entry)
    end
  else
    Struct.new("S3Entry", :key, :last_modified, :content_length)

    s3_options = Hash.new
    s3_options[:limit] = options[:max_keys] if options[:max_keys]

    stop = false

    begin
      response = @s3.client.list_objects(:bucket_name => @bucket, :prefix => @key)
      response[:contents].each do |object|
        entry = Struct::S3Entry.new(object[:key], object[:last_modified], object[:size].to_i)
        stop = display.call(entry)
        break if stop
      end
      break if stop || response[:contents].empty?
      s3_options.merge!(:marker => response[:contents].last[:key])
    end while response[:truncated]
  end
rescue Errno::EPIPE
  # ignore
end

