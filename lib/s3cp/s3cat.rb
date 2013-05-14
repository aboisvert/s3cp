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
require 'progressbar'
require 'tempfile'

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

  opts.on("--edit", "Edit mode") do |edit|
    options[:edit] = edit
  end

  opts.on("--head SIZE", "Download only 'head' part of the file mode, e.g. 4KB, 1024B, 2GB") do |size|
    options[:head] = S3CP.size_in_bytes(size)
  end

  opts.on("--tail SIZE", "Download only 'tail' part of the file mode, e.g. 4KB, 1024B, 2GB") do |size|
    options[:tail] = S3CP.size_in_bytes(size)
  end

  opts.on("--range START-END", "Download only range (in absolute positions) portion, e.g. 1GB-2GB, 16K-128k, 128k-, -128k") do |range|
    range_start, range_end = range.split("-")
    options[:range_start] = S3CP.size_in_bytes(range_start) if range_start && (!range_start.empty?)
    options[:range_end] = S3CP.size_in_bytes(range_end) - 1 if range_end && (!range_end.empty?)
    range_start, range_end = range.split("-")
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

begin
  @bucket, @prefix = S3CP.bucket_and_key(url)
  fail "Your URL looks funny, doesn't it?" unless @bucket

  S3CP.load_config()

  read_options = {}
  read_options[:debug] = options[:debug]
  read_options[:head] = options[:head] if options[:head]
  read_options[:tail] = options[:tail] if options[:tail]
  read_options[:range_start] = options[:range_start] if options[:range_start]
  read_options[:range_end] = options[:range_end] if options[:range_end]

  @s3 = S3CP.connect().buckets[@bucket]


  if options[:edit] && (options[:head] || options[:tail] || options[:range_start] || options[:range_end])
    fail "--edit option is not intended to be used with --head, --tail nor --range"
  end

  if options[:tty] || options[:edit]
    # store contents to file to display with PAGER
    size = @s3.objects[@prefix].content_length

    progress_bar = ProgressBar.new(File.basename(@prefix), size).tap do |p|
      p.file_transfer_mode
    end

    file = Tempfile.new(File.basename(@prefix) + '_')
    out = File.new(file.path, "wb")
    begin
      @s3.objects[@prefix].read_as_stream(read_options) do |chunk|
        out.write(chunk)
        progress_bar.inc chunk.size
      end
      progress_bar.finish
    ensure
      out.close()
    end
    if options[:edit]
      before_md5 = S3CP.md5(file.path)
      system "#{ENV['EDITOR'] || 'vi'} #{file.path}"
      if ($? == 0)
        if (S3CP.md5(file.path) != before_md5)
          ARGV.clear
          ARGV << file.path
          ARGV << url
          load "s3cp/s3cp.rb"
        else
          puts "File unchanged."
        end
      else
        puts "Edit aborted (result code #{$?})."
      end
    else
      system "#{ENV['PAGER'] || 'less'} #{file.path}"
    end
    file.delete()
  else
    @s3.objects[@prefix].read_as_stream(read_options) do |chunk|
      begin
        $stdout.print(chunk)
      rescue Errno::EPIPE
        break
      end
    end
  end

rescue => e
  $stderr.print "s3cat: [#{e.class}] #{e.message}\n"
  if options[:debug]
    $stderr.print e.backtrace.join("\n") + "\n"
  end
end

