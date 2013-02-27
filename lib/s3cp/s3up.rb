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

require 's3cp/version'
require 's3cp/utils'
require 'tempfile'

# Parse arguments
options = {}
options[:tty] = $stdout.isatty
options[:headers] = []

op = OptionParser.new do |opts|
  opts.banner = "s3up [s3_path]"
  opts.separator ''
  opts.separator 'Uploads data from STDIN to S3.'

  opts.on('--headers \'Header1: Header1Value\',\'Header2: Header2Value\'', Array, "Headers to set on the item in S3." ) do |h|
    options[:headers] += h
  end

  opts.on('--header \'Header: Value\'', "Header to set on the item in S3." ) do |h|
    options[:headers] += [h]
  end

  opts.on("--acl PERMISSION", "One of 'private', 'authenticated-read', 'public-read', 'public-read-write'") do |permission|
    options[:acl] = S3CP.validate_acl(permission)
  end

  opts.separator "        e.g.,"
  opts.separator "              HTTP headers: \'Content-Type: image/jpg\'"
  opts.separator "               AMZ headers: \'x-amz-acl: public-read\'"
  opts.separator ""

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

@headers = S3CP.headers_array_to_hash(options[:headers])

url = ARGV[0]

bucket, key = S3CP.bucket_and_key(url)
fail "Your URL looks funny, doesn't it?" unless bucket

S3CP.load_config()

@s3 = S3CP.connect()

# copy all of STDIN to a temp file
temp = Tempfile.new('s3cp')
while true
  begin
    data = STDIN.sysread(4 * 1024)
    temp.syswrite(data)
  rescue EOFError => e
    break
  end
end
temp.close
temp.open

# upload temp file
begin
  s3_options = {}
  S3CP.set_header_options(s3_options, @headers)
  s3_options[:acl] = options[:acl]
  @s3.buckets[bucket].objects[key].write(temp, s3_options)
  STDERR.puts "s3://#{bucket}/#{key} => #{S3CP.format_filesize(temp.size)} "
ensure
  # cleanup
  temp.close
  temp.delete
end

