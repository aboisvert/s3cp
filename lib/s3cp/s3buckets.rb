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

op = OptionParser.new do |opts|
  opts.banner = "s3buckets"

  opts.on("--verbose", "Verbose mode") do
    options[:verbose] = true
  end

  opts.on("--debug", "Verbose mode") do
    options[:debug] = true
  end

  opts.on("--create BUCKET_NAME", "Create bucket") do |bucket|
    options[:create] = bucket
  end

  opts.on("--delete BUCKET_NAME", "Delete an empty bucket") do |bucket|
    options[:delete] = bucket
  end

  opts.on("--enable-versioning BUCKET_NAME", "Enable versioning on bucket") do |bucket|
    options[:enable_versioning] = bucket
  end

  opts.on("--suspend-versioning BUCKET_NAME", "Suspend versioning on bucket") do |bucket|
    options[:suspend_versioning] = bucket
  end

  opts.on("--acl ACL", "ACL of new bucket. e.g., private, public_read, public_read_write, authenticated_read, log_delivery_write") do |acl|
    options[:acl] = acl
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts op
    exit
  end
end
op.parse!(ARGV)

S3CP.standard_exception_handling(options) do

  S3CP.load_config()
  s3 = S3CP.connect()

  if options[:create]
    name = options[:create]
    create_options = {}
    create_options[:acl] = options[:acl] if options[:acl]
    s3.buckets.create(name, create_options)
    puts "Bucket #{name} created."
  elsif options[:delete]
    name = options[:delete]
    s3.buckets[name].delete()
  elsif options[:enable_versioning]
    name = options[:enable_versioning]
    s3.buckets[name].enable_versioning()
  elsif options[:suspend_versioning]
    name = options[:suspend_versioning]
    s3.buckets[name].suspend_versioning()
  else
    s3.buckets.each do |bucket|
      puts bucket.name
    end
  end
end

