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

# Default options
options = {
  :verbose => false,
  :acl     => nil,
  :headers => []
}

# Setup cli params
op = OptionParser.new do |opts|
  opts.banner = "s3mod [path(s)]"

  opts.banner = <<-BANNER
    s3mod [path(s)] ([permission])

    Multiple paths with multiple wildcards are supported:
      s3://bucket/path/*foo/*/bar*.jpg

    LEGACY SUPPORT

    This tool still supports old paramater format:
      % s3mod [path] [permission]
    You are encouraged to use --acl instead of passing permission as last parameter.

    WARNINGS:

    1) Due to limitations in AWS's S3 API, when you use --headers all ACL
       properties are removed from the S3 object.

    2) Due to limitations in AWS's S3 API, this command fails on S3 objects
       larger then 5Gb.

  BANNER
  opts.separator ''

  opts.on("--verbose", "Verbose mode") do
    options[:verbose] = true
  end

  opts.on("--debug", "Debug mode") do
    options[:debug] = true
  end

  opts.on('--headers \'Header1: Header1Value\',\'Header2: Header2Value\'', Array, "Headers to set on the item in S3." ) do |h|
    options[:headers] += h
  end

  opts.on('--header \'Header: Value\'', "Header to set on the item in S3." ) do |h|
    options[:headers] += [h]
  end

  opts.on("--acl PERMISSION", "One of 'private', 'authenticated-read', 'public-read', 'public-read-write'") do |permission|
    options[:acl] = S3CP.validate_acl(permission)
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts op
    exit
  end
end

op.parse!(ARGV)
paths = ARGV

if ARGV.size < 1 || !options[:headers]
  puts op
  exit
end

# Legacy (support for s3mod [path] [acl] )
# See if last param starts with "s3://", validate & remove it from list of paths
if !options[:acl] && paths.size > 1 && S3CP::LEGAL_MODS.include?(paths.last)
  options[:acl] = S3CP.validate_acl(paths.pop);
end

begin
  S3CP.load_config()
  @s3 = S3CP.connect()

  paths.each do |path|
    bucket,key = S3CP.bucket_and_key(path)
    fail "Invalid bucket/key: #{path}" unless key

    S3CP.objects_by_wildcard(@s3.buckets[bucket], key) { | obj |
      puts "s3://#{bucket}/#{obj.key}"

      if options[:headers].size > 0
        current_medata = obj.metadata
        object_metadata = S3CP.set_header_options(current_medata, S3CP.headers_array_to_hash(options[:headers]))
      end

      if options[:acl]
        obj.acl = options[:acl]
      end
    }
  end
rescue => e
  $stderr.print "s3mod: [#{e.class}] #{e.message}\n"
  if options[:debug]
    $stderr.print e.backtrace.join("\n") + "\n"
  end
end
