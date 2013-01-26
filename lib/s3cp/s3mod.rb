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
  :verbose => $stdout.isatty ? true : false,
  :acl     => nil,
  :headers => []
}

# Setup cli params
op = OptionParser.new do |opts|
  opts.banner = "s3mod [path(s)]"

  opts.banner = <<-BANNER
    s3mod [path(s)] ([permission])

    Warning!
    Due to limitations in AWS's S3 API all existing headers are removed
    when you modify/set new headers. In addition to that, if you use --headers,
    all ACL properties are removed from the S3 object. 
    If you use only --acl param to fix the permissions, object's headers are preserved

    If you are modifying headers on S3 objects larger then 5Gb, this command will 
    fail due to limitations in AWS S3.

    Multiple paths with multiple wildcards are supported:
      s3://bucket/path/*foo/*/bar*.jpg
      
    Legacy support
    This tool still supports old param format:
      s3mod path permission

  BANNER
  opts.separator ''

  opts.on("--verbose", "Verbose mode") do
    options[:verbose] = true
  end

  opts.on('--headers \'Header1: Header1Value\',\'Header2: Header2Value\'', Array, "Headers to set on the item in S3." ) do |h|
    options[:headers] = h
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
if ! options[:acl] && paths.size > 1 && ! paths.last.start_with?('s3://') 
  options[:acl] = S3CP.validate_acl(paths.pop);
end


@verbose = options[:verbose]
def log(msg)
  puts msg if @verbose
end

# this probaby has some potential for other tools as well
def objects_by_wildcard(bucket, key, &block)
  
  # First, trim multiple wildcards & wildcards on the end
  key = key.gsub(/\*+/, '*')

  if 0 < key.count('*')
    key_split = key.split('*', 2);
    kpfix     = key_split.shift(); # ignore first part as AWS API takes it as a prefix
    regex     = []
    
    key_split.each do |kpart| 
      regex.push Regexp.quote(kpart)
    end

    regex = regex.empty? ? nil : Regexp.new(regex.join('.*') + '$');

    bucket.objects.with_prefix(kpfix).each do |obj|
      yield obj if regex == nil || regex.match(obj.key, kpfix.size)
    end
  else
    # no wildcards, simple:
    yield bucket.objects[key]
  end
end

object_metadata = S3CP.set_header_options({}, S3CP.headers_array_to_hash(options[:headers]))

S3CP.load_config()
@s3 = S3CP.connect()

paths.each do |path|
  bucket,key = S3CP.bucket_and_key(path)

  objects_by_wildcard(@s3.buckets[bucket], key) { | obj |
    log obj.key

    if options[:headers].size > 0
      log "  - setting headers"   
      obj.copy_to(obj.key, object_metadata);
    end

    if options[:acl]
      log "  - setting acl"
      obj.acl = options[:acl]
    end
  }
end