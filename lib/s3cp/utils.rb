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

require 'rubygems'
require 'extensions/kernel' if RUBY_VERSION =~ /1.8/
require 'aws/s3'
require 'optparse'
require 'date'
require 'highline/import'
require 's3cp/version'
require 'fileutils'

module S3CP
  extend self

  # Valid units for file size formatting
  UNITS = %w{B KB MB GB TB EB ZB YB BB}

  LEGAL_MODS = %w{
    private
    public-read
    public-read-write
    authenticated-read
    bucket_owner_read
    bucket_owner_full_control
  }

  # Connect to AWS S3
  def connect()
    options = {}

    # optional region override
    region = ENV["S3CP_REGION"]
    options[:s3_endpoint] = "s3-#{region}.amazonaws.com" if region && region != "us-east-1"

    # optional endpoint override
    endpoint = ENV["S3CP_ENDPOINT"]
    options[:s3_endpoint] = endpoint if endpoint

    ::AWS::S3.new(options)
  end

  # Load user-defined configuration file (e.g. to initialize AWS.config object)
  def load_config()
    aws_config = File.join(ENV['HOME'], '.s3cp') if ENV['HOME']
    aws_config = ENV['S3CP_CONFIG'] if ENV['S3CP_CONFIG']
    if aws_config && File.exist?(aws_config)
      load aws_config
    end
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

  # Calculate the MD5 checksum for the given file
  def md5(filename)
    digest = Digest::MD5.new()
    file = File.open(filename, 'r')
    begin
      file.each_line do |line|
        digest << line
      end
    ensure
      file.close()
    end
    digest.hexdigest
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

  def set_header_options(options, headers)
    return options unless headers

    # legacy options that were previously passed as headers
    # are now passed explicitly as options/metadata.
    mappings = {
      "Content-Type"  =>  :content_type,
      "x-amz-acl"     =>  :acl,
      "Cache-Control" =>  :cache_control,
      "x-amz-storage-class" => :reduced_redundancy
    }

    lambdas = {
      "x-amz-storage-class" => lambda { |v| (v =~ /^REDUCED_REDUNDANCY$/i) ? true : false }
    }

    remaining = headers.dup
    headers.each do |hk, hv|
      mappings.each do |mk, mv|
        if hk.to_s =~ /^#{mk}$/i
          lambda = lambdas[mk]
          options[mv] = lambda ? lambda.call(hv) : hv
          remaining.delete(hk)
        end
      end
    end


    options[:metadata] = remaining unless remaining.empty?

    options
  end

  def validate_acl(permission)
    if !LEGAL_MODS.include?(permission)
      raise "Permissions must be one of the following values: #{LEGAL_MODS}"
    end
    permission
  end
end

# Monkey-patch S3 object for download streaming
# https://forums.aws.amazon.com/thread.jspa?messageID=295587
module AWS

  DEFAULT_STREAMING_CHUNK_SIZE = ENV["S3CP_STREAMING_CHUNK_SIZE"] ? ENV["S3CP_STREAMING_CHUNK_SIZE"].to_i : (512 * 1024)

  class S3
    class S3Object
      def read_as_stream(options = nil, &blk)
        options ||= {}
        chunk_size = options[:chunk] || DEFAULT_STREAMING_CHUNK_SIZE
        size = content_length
        byte_offset = 0
        while byte_offset < size
          range = "bytes=#{byte_offset}-#{byte_offset + chunk_size - 1}"
          yield read(:range => range)
          byte_offset += chunk_size
        end
      end
    end
  end
end

# Monkey-patch to add requester-pays support (experimental)
# http://docs.amazonwebservices.com/AmazonS3/latest/dev/ObjectsinRequesterPaysBuckets.html
if ENV["S3CP_REQUESTER_PAYS"] =~ /(yes|on|1)/i
  class AWS::S3::Request
    def canonicalized_headers
      headers["x-amz-request-payer"] = 'requester' # magic!
      x_amz = headers.select{|name, value| name.to_s =~ /^x-amz-/i }
      x_amz = x_amz.collect{|name, value| [name.downcase, value] }
      x_amz = x_amz.sort_by{|name, value| name }
      x_amz = x_amz.collect{|name, value| "#{name}:#{value}" }.join("\n")
      x_amz == '' ? nil : x_amz
    end
  end
end
