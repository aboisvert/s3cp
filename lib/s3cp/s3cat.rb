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
require 'tempfile'

require 's3cp/utils'

# Parse arguments
options = {}
options[:tty] = $stdout.isatty

op = OptionParser.new do |opts|
  opts.banner = "s3cat [path]"
  opts.separator ''

  opts.on("--debug", "Debug mode") do
    options[:debug] = true
  end

  opts.on("--tty", "TTY mode") do |tty|
    options[:tty] = tty
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

if options[:debug]
  puts "URL: #{url}"
  puts "Options: \n#{options.inspect}"
end

@bucket, @prefix = S3CP.bucket_and_key(url)
fail "Your URL looks funny, doesn't it?" unless @bucket

@s3 = S3CP.connect().interface

if options[:tty]
  # store contents to file to display with PAGER
  file = Tempfile.new('s3cat')
  out = File.new(file.path, "wb")
  begin
    @s3.get(@bucket, @prefix) do |chunk|
      out.write(chunk)
    end
  ensure
    out.close()
  end
  exec "#{ENV['PAGER'] || 'less'} #{file.path}"
  file.delete()
else
  @s3.get(@bucket, @prefix) do |chunk|
    begin
      STDOUT.print(chunk)
    rescue Errno::EPIPE
      break
    end
  end
end

