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

  opts.on_tail("-h", "--help", "Show this message") do
    puts op
    exit
  end
end
op.parse!(ARGV)

S3CP.load_config()

begin
  s3 = S3CP.connect()
  s3.buckets.each do |bucket|
    puts bucket.name
  end
rescue => e
  $stderr.print "s3buckets: [#{e.class}] #{e.message}\n"
  if options[:debug]
    $stderr.print e.backtrace.join("\n") + "\n"
  end
end

