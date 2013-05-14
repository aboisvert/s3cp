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

@options = {}

op = OptionParser.new do |opts|
  opts.banner = "s3stat [path]"

  opts.on("--acl", "Display Access Control List XML document") do
    @options[:acl] = true
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts op
    exit
  end
end

op.parse!(ARGV)

if ARGV.size < 1
  puts op
  exit
end

source  = ARGV[0]
permission = ARGV.last

@bucket, @key = S3CP.bucket_and_key(source)
fail "Your URL looks funny, doesn't it?" unless @bucket

S3CP.standard_exception_handling(options) do
  S3CP.load_config()

  @s3 = S3CP.connect().buckets[@bucket]

  obj = @s3.objects[@key]

  metadata = obj.head
  metadata.to_h.keys.sort { |k1, k2| k1.to_s <=> k2.to_s}.each do |k|
    puts "#{"%30s" % k} #{metadata[k].is_a?(Hash) ? metadata[k].inspect : metadata[k].to_s}"
  end

  if @options[:acl]
    puts
    xml = Nokogiri::XML(obj.acl.to_s)
    puts xml.to_s
  end
end
