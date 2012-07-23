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
options[:precision] = 0
options[:unit]      = nil
options[:depth]     = 0
options[:regex]     = nil

op = OptionParser.new do |opts|
  opts.banner = "s3du [path]  # Display disk usage"
  opts.separator ''

  opts.on("--unit UNIT", "Force unit to use for file size display: #{S3CP::UNITS.join(', ')}.") do |unit|
    options[:unit] = unit
  end

  opts.on("--precision PRECISION", "Precision used to display sizes, e.g. 3 => 0.123GB. (default 0)") do |precision|
    options[:precision] = precision.to_i
  end

  opts.on("--depth DEPTH", "Depth to report space usage (default 0).") do |depth|
    options[:depth] = depth.to_i
  end

  opts.on("--regex REGEX", "Regular expression to match keys.") do |regex|
    options[:regex] = Regexp.new(regex)
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

@options = options

@bucket, @prefix = S3CP.bucket_and_key(url)
fail "Your URL looks funny, doesn't it?" unless @bucket

@s3 = S3CP.connect()

def depth(path)
  path.count("/")
end

# Returns the index of the nth occurrence of substr if it exists, otherwise -1
def nth_occurrence(str, substr, n)
  pos = -1
  if n > 0 && str.include?(substr)
    i = 0
    while i < n do
      pos = str.index(substr, pos + substr.length) if pos != nil
      i += 1
    end
  end
  pos != nil && pos != -1 ? pos + 1 : -1
end

last_key     = nil
actual_depth = depth(@prefix) + options[:depth] if options[:depth]
total_size    = 0
subtotal_size = 0

def print(key, size)
  size = S3CP.format_filesize(size, :unit => @options[:unit], :precision => @options[:precision])
  puts ("%#{7 + @options[:precision]}s " % size) + key
end

begin
  @s3.buckets[@bucket].objects.with_prefix(@prefix).each do |entry|
    key  = entry.key
    size = entry.content_length

    if options[:regex].nil? || options[:regex].match(key)
      current_key = if actual_depth
        pos = nth_occurrence(key, "/", actual_depth)
        (pos != -1) ? key[0..pos-1] : key
      end

      if (last_key && last_key != current_key)
        print(last_key, subtotal_size)
        subtotal_size = size
      else
        subtotal_size += size
      end

      last_key = current_key
      total_size += size
    end
  end

  if last_key != nil
    print(last_key, subtotal_size)
  end

  if options[:depth] > 0
    print("", total_size)
  else
    puts S3CP.format_filesize(total_size, :unit => options[:unit], :precision => options[:precision])
  end
rescue Errno::EPIPE
  # ignore
end

