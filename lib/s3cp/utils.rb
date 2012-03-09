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

  # Valid units for file size formatting
  UNITS = %w{B KB MB GB TB EB ZB YB BB}

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

  def headers_array_to_hash(header_array)
    headers = {}
    header_array.each do |header|
      header_parts = header.split(": ", 2)
      if header_parts.size == 2
        headers[header_parts[0].downcase] = header_parts[1]  # RightAWS gem expect lowercase header names :(
      else
        fail("Invalid header value; expected single colon delimiter; e.g. Header: Value")
      end
    end
    headers
  end

  # Round a number at some `decimals` level of precision.
  def round(n, decimals = 0)
    (n * (10.0 ** decimals)).round * (10.0 ** (-decimals))
  end

  # Return a formatted string for a file size.
  #
  # Valid units are "b" (bytes), "kb" (kilobytes), "mb" (megabytes),
  # "gb" (gigabytes), "tb" (terabytes), "eb" (exabytes), "zb" (zettabytes),
  # "yb" (yottabytes), "bb" (brontobytes) and their uppercase equivalents.
  #
  # If :unit option isn't specified, the "best" unit is automatically picked.
  # If :precision option isn't specified, the number is rounded to closest integer.
  #
  # e.g.  format_filesize( 512, :unit => "b",  :precision => 2) =>    "512B"
  #       format_filesize( 512, :unit => "kb", :precision => 4) =>   "0.5KB"
  #       format_filesize(1512, :unit => "kb", :precision => 3) => "1.477KB"
  #
  #       format_filesize(11789512) => "11MB"  # smart unit selection
  #
  #       format_filesize(11789512, :precision => 2) => "11.24MB"
  #
  def format_filesize(num, options = {})
    precision = options[:precision] || 0
    if options[:unit]
      unit = options[:unit].upcase
      fail "Invalid unit" unless UNITS.include?(unit)
      num = num.to_f
      for u in UNITS
        if u == unit
          s = "%0.#{precision}f" % round(num, precision)
          return s + unit
        end
        num = num / 1024
      end
    else
      e = (num == 0) ? 0 : (Math.log(num) / Math.log(1024)).floor
      s = "%0.#{precision}f" % round((num.to_f / 1024**e), precision)
      s + UNITS[e]
    end
  end

end

