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

op = OptionParser.new do |opts|
  opts.banner = "s3mod [path] [permission]"

  opts.separator ""
  opts.separator "where [permission] is one of:"
  opts.separator ""
  opts.separator " * private"
  opts.separator " * authenticated-read"
  opts.separator " * public-read"
  opts.separator " * public-read-write"
  opts.separator ""

  opts.on_tail("-h", "--help", "Show this message") do
    puts op
    exit
  end
end

op.parse!(ARGV)

if ARGV.size < 2
  puts op
  exit
end

def update_permissions(s3, bucket, key, permission)
  puts "Setting #{permission} on s3://#{bucket}/#{key}"
  s3.buckets[bucket].objects[key].acl = permission
end

source  = ARGV[0]
permission = S3CP.validate_acl(ARGV.last)

@s3 = S3CP.connect()
bucket,key = S3CP.bucket_and_key(source)
update_permissions(@s3, bucket, key, permission)
