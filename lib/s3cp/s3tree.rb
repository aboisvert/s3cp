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
options[:rows_per_page] = ($terminal.output_rows - 1) if $stdout.isatty
options[:delimiter] = ENV["S3CP_DELIMITER"] || "/"
options[:max_depth] = 9999999

op = OptionParser.new do |opts|
  opts.banner = "s3tree [path]"
  opts.separator ''

  opts.on("-d", "Show directories only") do
    options[:directories_only] = true
  end

  opts.on("--rows ROWS", "Rows per page") do |rows|
    options[:rows_per_page] = rows.to_i
  end

  opts.on("--max-keys KEYS", "Maximum number of keys to display") do |keys|
    options[:max_keys] = keys.to_i
  end

  opts.on("--max-depth DEPTH", "Maximum directory depth to display") do |depth|
    options[:max_depth] = depth.to_i
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

@bucket, @key = S3CP.bucket_and_key(url)
fail "Your URL looks funny, doesn't it?" unless @bucket

S3CP.load_config()

@s3 = S3CP.connect().buckets[@bucket]

keys = 0
rows = 0

begin
  # find last index of character `ch` in `str`.
  last_index_of = lambda do |str, ch|
    case
      when str[ch] then str.length-(str.reverse.index(ch)+1)
      else -1
    end
  end

  # displays the next line, returns true if user interrupts or max keys shown
  display_line = lambda do |line|
    puts line
    keys += 1
    if options[:max_keys] && keys > options[:max_keys]
      return true
    end
    rows += 1
    response = ''
    if options[:rows_per_page] && (rows % options[:rows_per_page] == 0)
      begin
        print "Continue? (Y/n) "
        response = STDIN.gets.chomp.downcase
      end until response == 'n' || response == 'y' || response == ''
    end
    (response == 'n')
  end

  # returns relative path against @key
  #
  # e.g. relative.call("foo/bar") => "bar"   (assuming @key = "foo/")
  #
  relative = lambda do |key|
    last_delimiter = last_index_of.call(@key, options[:delimiter])
    (last_delimiter != -1) ? key[last_delimiter..-1] : key
  end

  # trim up to the last delimiter
  #
  # e.g. trim.call("foo/bar") => "foo/"
  #
  trim = lambda do |key|
    last_delimiter = last_index_of.call(key, options[:delimiter])
    (last_delimiter != -1) ? key[0..last_delimiter] : ""
  end

  # recursively display tree elements
  #
  # +prefix+: line prefix
  # +children+: children of the current directory
  # +depth+: current directory depth
  display_tree = lambda do |prefix, children, depth|
    stop = false
    children = children.to_a  # aws-sdk returns a sucky ChildCollection object
    children.each_with_index do |node, index|
      node = node
      if options[:directories_only] && node.leaf?
        next
      end

      last = (index == children.size - 1)
      has_siblings = (children.size > 1)
      key = node.branch? ? node.prefix : node.key
      parts = relative.call(key).split(options[:delimiter])
      postfix = last ? '└── ' : '├── '

      stop = display_line.call(prefix + postfix + parts.last)
      break if stop

      if node.branch? && depth < options[:max_depth]
        new_prefix = prefix + (has_siblings ? "│    " : "    ")
        stop = display_tree.call(new_prefix, node.children, depth + 1)
        break if stop
      end

      break if stop
    end
    stop
  end

  display_line.call("s3://#{@bucket}/#{trim.call(@key)}")

  prefix = ""
  root = @s3.objects.with_prefix(@key).as_tree( :delimier => options[:delimiter], :append => false)
  depth = 1
  display_tree.call(prefix, root.children, depth)
rescue Errno::EPIPE
  # ignore
end

