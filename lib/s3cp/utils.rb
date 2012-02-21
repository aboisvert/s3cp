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

module S3CP
  extend self

  # Connect to AWS S3
  def connect()
    access_key = ENV["AWS_ACCESS_KEY_ID"]     || raise("Missing environment variable AWS_ACCESS_KEY_ID")
    secret_key = ENV["AWS_SECRET_ACCESS_KEY"] || raise("Missing environment variable AWS_SECRET_ACCESS_KEY")

    logger = Logger.new('/dev/null')
    RightAws::S3.new(access_key, secret_key, :logger => logger)
  end

  # Parse URL and return bucket and key.
  #
  # e.g. s3://bucket/path/to/key => ["bucket", "path/to/key"]
  #      bucket:path/to/key => ["bucket", "path/to/key"]
  def bucket_and_key(url)
    if url =~ /s3:\/\/([^\/]+)\/?(.*)/
      bucket = $1
      key = $2
    elsif url =~ /([^:]+):(.*)/
      bucket = $1
      key = $2
    end
    [bucket, key]
  end
end

