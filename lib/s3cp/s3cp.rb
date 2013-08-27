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
require 'progressbar'

# Parse arguments
options = {}
options[:verbose] = $stdout.isatty ? true : false
options[:headers] = []
options[:overwrite]   = ENV["S3CP_OVERWRITE"]   ? (ENV["S3CP_OVERWRITE"] =~ /y|yes|true|1|^\s*$/i ? true : false) : true
options[:checksum]    = ENV["S3CP_CHECKSUM"]    ? (ENV["S3CP_CHECKSUM"]  =~ /y|yes|true|1|^\s*$/i ? true : false) : true
options[:retries]     = ENV["S3CP_RETRIES"]     ? ENV["S3CP_RETRIES"].to_i     : 18
options[:retry_delay] = ENV["S3CP_RETRY_DELAY"] ? ENV["S3CP_RETRY_DELAY"].to_i : 1
options[:retry_backoff] = ENV["S3CP_BACKOFF"]   ? ENV["S3CP_BACKOFF"].to_f     : 1.4142 # double every 2 tries
options[:multipart] = case ENV["S3CP_MULTIPART"]
  when /n|no|false/i
    false
  when /\d+/
    ENV["S3CP_MULTIPART"].to_i
  else
    true
  end
options[:include_regex] = []
options[:exclude_regex] = []
options[:sync] = false
options[:move] = false
options[:mkdir] = nil

op = OptionParser.new do |opts|
  opts.banner = <<-BANNER
    s3cp supports 4 copying use cases:
      1. Copy from local machine to S3
      2. Copy from S3 to local machine
      3. Copy from S3 to S3
      4. Copy from local machine to another path on local machine (for completeness)

    Local to S3:
      s3cp LOCAL_PATH S3_PATH

    S3 to Local:
      s3cp S3_PATH LOCAL_PATH

    S3 to S3:
      s3cp S3_PATH S3_PATH2

    Local to Local:
      s3cp LOCAL_PATH LOCAL_PATH2

  BANNER
  opts.separator ''

  opts.on("-r", "--recursive", "Recursive mode") do
    options[:recursive] = true
  end

  opts.on("--no-overwrite", "Does not overwrite existing files") do
    options[:overwrite] = false
  end

  opts.on("--sync", "Sync mode: use checksum to determine if files need copying.") do
    options[:sync] = true
  end

  opts.on("--move", "Move mode: delete original file(s) after copying.") do
    options[:move] = true
  end

  opts.on("--mkdir MATCH", "Recreate directory structure starting at `MATCH` from source path(s)") do |prefix|
    options[:mkdir] = Regexp.new(prefix)
  end

  opts.on("--max-attempts N", "Number of attempts to upload/download until checksum matches (default #{options[:retries]})") do |attempts|
    options[:retries] = attempts.to_i
  end

  opts.on("--retry-delay SECONDS", "Time to wait (in seconds) between retries (default #{options[:retry_delay]})") do |delay|
    options[:retry_delay] = delay.to_i
  end

  opts.on("--retry-backoff FACTOR", "Exponential backoff factor (default #{options[:retry_backoff]})") do |factor|
    options[:retry_backoff] = factor.to_f
  end

  opts.on("--no-checksum", "Disable checksum checking") do
    options[:checksum] = false
  end

  opts.separator ""

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

  opts.on("-i REGEX", "--include REGEX", "Copy only files matching the following regular expression.") do |regex|
    options[:include_regex] << regex
  end

  opts.on("-x REGEX", "--exclude REGEX", "Do not copy files matching provided regular expression.") do |regex|
    options[:exclude_regex] << regex
  end

  opts.on("--verbose", "Verbose mode") do
    options[:verbose] = true
  end

  opts.on("--debug", "Debug mode") do
    options[:debug] = true
  end

  opts.on("--version", "Display version information") do
    puts S3CP::VERSION
    exit
  end

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

if options[:include_regex].any? && !options[:recursive]
  $stderr.puts "-i (--include regex) option requires -r (recursive) option."
  exit(1)
end

if options[:exclude_regex].any? && !options[:recursive]
  $stderr.puts "-x (--exclude regex) option requires -r (recursive) option."
  exit(1)
end

destination = ARGV.last
sources = ARGV[0..-2]

if options[:debug]
  $stderr.puts "sources: #{sources.inspect}"
  $stderr.puts "destination: #{destination}"
  $stderr.puts "Options: \n#{options.inspect}"
end

class ProxyIO
  instance_methods.each { |m| undef_method m unless m =~ /(^__|^send$|^object_id$)/ }

  def initialize(io, progress_bar)
    @io = io
    @progress_bar = progress_bar
  end

  def read(size)
    result = @io.read(size)
    @progress_bar.inc result.length if result && @progress_bar
    result
  end

  protected

  def method_missing(name, *args, &block)
    #puts "ProxyIO method_missing! #{name} #{args.inspect}"
    @io.send(name, *args, &block)
  end
end

def s3?(url)
  S3CP.bucket_and_key(url)[0]
end

if options[:verbose]
  @verbose = true
end

@includes = options[:include_regex].map { |s| Regexp.new(s) }
@excludes = options[:exclude_regex].map { |s| Regexp.new(s) }

S3CP.load_config()

@s3 = S3CP.connect()

def direction(from, to)
  if s3?(from) && s3?(to)
    :s3_to_s3
  elsif !s3?(from) && s3?(to)
    :local_to_s3
  elsif s3?(from) && !s3?(to)
    :s3_to_local
  else
    :local_to_local
  end
end

def match(path)
  matching = true
  return false if @includes.any? && !@includes.any? { |regex| regex.match(path) }
  return false if @excludes.any? &&  @excludes.any? { |regex| regex.match(path) }
  true
end

def no_slash(path)
  path = path.match(/\/$/) ? path[0..-2] : path
  path.match(/^\//) ? path[1..-1] : path
end

# relative("path/to/", "path/to/file") => "file"
# relative("path/to",  "path/to/file") => "to/file"
def relative(base, path)
  dir = base.rindex("/") ? base[0..base.rindex("/")] : ""
  no_slash(path[dir.length..-1])
end

def mkdir_relative(regex, key)
  m = regex.match(key) or return
  pos = m.captures.empty? ? m.begin(0) : m.begin(1)
  suffix = key[pos..-1]
end

def log(msg)
  puts msg if @verbose
end

@headers = S3CP.headers_array_to_hash(options[:headers])

def with_headers(msg)
  unless @headers.empty?
    msg += " with headers:"
    msg += @headers.collect{|k,v| "'#{k}: #{v}'"}.join(", ")
  end
  msg
end

def operation(options)
  operation = "Copy"
  operation = "Move" if options[:move]
  operation = "Sync" if options[:sync]
  operation
end

def s3_to_s3(bucket_from, key, bucket_to, dest, options = {})
  log(with_headers("#{operation(options)} s3://#{bucket_from}/#{key} to s3://#{bucket_to}/#{dest}"))
  s3_source = @s3.buckets[bucket_from].objects[key]
  s3_dest = @s3.buckets[bucket_to].objects[dest]
  s3_options = {}
  S3CP.set_header_options(s3_options, @headers)
  s3_options[:acl] = options[:acl] if options[:acl]
  unless options[:move]
    s3_source.copy_to(s3_dest, s3_options)
  else
    s3_source.move_to(s3_dest, s3_options)
  end
end

def local_to_s3(bucket_to, key, file, options = {})
  log(with_headers("#{operation(options)} #{file} to s3://#{bucket_to}/#{key}"))

  expected_md5 = if options[:checksum] || options[:sync]
     S3CP.md5(file)
  end

  actual_md5 = if options[:sync]
    md5 = s3_checksum(bucket_to, key)
    case md5
    when :not_found
      nil
    when :invalid
      $stderr.puts "Warning: No MD5 checksum available and ETag not suitable due to multi-part upload; file will be force-copied."
      nil
    else
      md5
    end
  end

  if actual_md5.nil? || (options[:sync] && expected_md5 != actual_md5)
    retries = 0
    begin
      if retries == options[:retries]
        fail "Unable to upload to s3://#{bucket_to}/#{key} after #{retries} attempts."
      end
      if retries > 0
        delay = options[:retry_delay] * (options[:retry_backoff] ** retries)
        $stderr.puts "Sleeping #{"%0.2f" % delay} seconds.  Will retry #{options[:retries] - retries} more time(s)."
        sleep delay
      end

      begin
        obj = @s3.buckets[bucket_to].objects[key]

        s3_options = {}
        S3CP.set_header_options(s3_options, @headers)
        s3_options[:acl] = options[:acl] if options[:acl]
        s3_options[:content_length] = File.size(file)

        multipart_threshold = options[:multipart].is_a?(Fixnum) ?  options[:multipart] : AWS.config.s3_multipart_threshold
        if (expected_md5 != nil) && (File.size(file) >= multipart_threshold) && options[:multipart]
          meta = s3_options[:metadata] || {}
          meta[:md5] = expected_md5
          s3_options[:metadata] = meta
        end

        if options[:multipart]
          s3_options[:multipart_threshold] = multipart_threshold
        else
          s3_options[:single_request] = true
        end

        progress_bar = if $stdout.isatty
          ProgressBar.new(File.basename(file), File.size(file)).tap do |p|
            p.file_transfer_mode
          end
        end

        File.open(file) do |io|
          obj.write(ProxyIO.new(io, progress_bar), s3_options)
        end

        progress_bar.finish if progress_bar

        if options[:checksum]
          actual_md5 = s3_checksum(bucket_to, key)
          if actual_md5.is_a? String
            if actual_md5 != expected_md5
              $stderr.puts "Warning: invalid MD5 checksum.  Expected: #{expected_md5} Actual: #{actual_md5}"
            end
          else
            $stderr.puts "Warning: invalid MD5 checksum in metadata: #{actual_md5.inspect}; skipped checksum verification."
            actual_md5 = nil
          end
        end
      rescue => e
        actual_md5 = "bad"
        if progress_bar
          progress_bar.clear
          $stderr.puts "Error copying #{file} to s3://#{bucket_to}/#{key}"
        end
        raise e if !options[:checksum] || e.is_a?(AWS::S3::Errors::AccessDenied)
        $stderr.puts e
      end
      retries += 1
    end until options[:checksum] == false || actual_md5.nil? || expected_md5 == actual_md5
  else
    log "Already synchronized."
  end
  FileUtils.rm file if options[:move]
end

def s3_to_local(bucket_from, key_from, dest, options = {})
  log("#{operation(options)} s3://#{bucket_from}/#{key_from} to #{dest}")
  raise ArgumentError, "source key may not be blank" if key_from.to_s.empty?

  retries = 0
  begin
    if retries == options[:retries]
      File.delete(dest) if File.exist?(dest)
      fail "Unable to download s3://#{bucket_from}/#{key_from} after #{retries} attempts."
    end
    if retries > 0
      delay = options[:retry_delay] * (options[:retry_backoff] ** retries)
      delay = delay.to_i
      $stderr.puts "Sleeping #{"%0.2f" % delay} seconds.  Will retry #{options[:retries] - retries} more time(s)."
      sleep delay
    end
    begin
      expected_md5 = if options[:checksum] || options[:sync]
        md5 = s3_checksum(bucket_from, key_from)
        if options[:sync] && !md5.is_a?(String)
          $stderr.puts "Warning: invalid MD5 checksum in metadata; file will be force-copied."
          nil
        elsif !md5.is_a? String
          $stderr.puts "Warning: invalid MD5 checksum in metadata; skipped checksum verification."
          nil
        else
          md5
        end
      end

      actual_md5 = if options[:sync] && File.exist?(dest)
         S3CP.md5(dest)
      end

      if !options[:sync] || expected_md5.nil? || (expected_md5 != actual_md5)
        f = File.new(dest, "wb")
        begin
          progress_bar = if $stdout.isatty
            size = s3_size(bucket_from, key_from)
            ProgressBar.new(File.basename(key_from), size).tap do |p|
              p.file_transfer_mode
            end
          end
          @s3.buckets[bucket_from].objects[key_from].read_as_stream do |chunk|
            f.write(chunk)
            progress_bar.inc chunk.size if progress_bar
          end
          progress_bar.finish if progress_bar
        rescue => e
          progress_bar.halt if progress_bar
          raise e
        ensure
          f.close()
        end
      else
        log("Already synchronized")
        return
      end
    rescue => e
      raise e if e.is_a?(AWS::S3::Errors::NoSuchKey)
      raise e unless options[:checksum]
      $stderr.puts e
    end

    if options[:checksum] && expected_md5 != nil
      actual_md5 = S3CP.md5(dest)
      if actual_md5 != expected_md5
        $stderr.puts "Warning: invalid MD5 checksum.  Expected: #{expected_md5} Actual: #{actual_md5}"
      end
    end

    retries += 1
  end until options[:checksum] == false || expected_md5.nil? || S3CP.md5(dest) == expected_md5

  @s3.buckets[bucket_from].objects[key_from].delete() if options[:move]
end

def s3_exist?(bucket, key)
  @s3.buckets[bucket].objects[key].exists?
end

def s3_checksum(bucket, key)
  begin
    metadata = @s3.buckets[bucket].objects[key].head()
    return :not_found unless metadata
  rescue => e
    return :not_found if e.is_a?(AWS::S3::Errors::NoSuchKey)
    raise e
  end

  case
  when metadata[:meta] && metadata[:meta]["md5"]
    metadata[:meta]["md5"]
  when metadata[:etag] && metadata[:etag] !~ /-/
    metadata[:etag].sub(/^"/, "").sub(/"$/, "") # strip beginning and trailing quotes
  else
    :invalid
  end
end

def key_path(prefix, key)
  if (prefix.nil? || prefix.strip == '')
    key
  else
    no_slash(prefix) + '/' + key
  end
end

def s3_size(bucket, key)
  @s3.buckets[bucket].objects[key].content_length
end

def copy(from, to, options)
  bucket_from, key_from = S3CP.bucket_and_key(from)
  bucket_to, key_to = S3CP.bucket_and_key(to)

  case direction(from, to)
  when :s3_to_s3
    if options[:recursive]
      keys = []
      @s3.buckets[bucket_from].objects.with_prefix(key_from).each do |entry|
        keys << entry.key
      end
      keys.each do |key|
        if match(key)
          dest = key_path key_to, relative(key_from, key)
          if !options[:overwrite] && s3_exist?(bucket_to, dest)
            $stderr.puts "Skipping s3://#{bucket_to}/#{dest} - already exists."
          else
            s3_to_s3(bucket_from, key, bucket_to, dest, options)
          end
        end
      end
    else
      key_to += File.basename(key_from) if key_to[-1..-1] == "/"
      if !options[:overwrite] && s3_exist?(bucket_to, key_to)
        $stderr.puts "Skipping s3://#{bucket_to}/#{key_to} - already exists."
      else
        s3_to_s3(bucket_from, key_from, bucket_to, key_to, options)
      end
    end
  when :local_to_s3
    if options[:recursive]
      files = Dir[from + "/**/*"]
      files.each do |f|
        if File.file?(f) && match(f)
          #puts "bucket_to #{bucket_to}"
          #puts "no_slash(key_to) #{no_slash(key_to)}"
          #puts "relative(from, f) #{relative(from, f)}"
          key = key_path key_to, relative(from, f)
          if !options[:overwrite] && s3_exist?(bucket_to, key)
            $stderr.puts "Skipping s3://#{bucket_to}/#{key} - already exists."
          else
            local_to_s3(bucket_to, key, File.expand_path(f), options)
          end
        end
      end
    else
      key_to += File.basename(from) if key_to[-1..-1] == "/"
      if !options[:overwrite] && s3_exist?(bucket_to, key_to)
        $stderr.puts "Skipping s3://#{bucket_to}/#{key_to} - already exists."
      else
        local_to_s3(bucket_to, key_to, File.expand_path(from), options)
      end
    end
  when :s3_to_local
    if options[:recursive]
      keys = []
      @s3.buckets[bucket_from].objects.with_prefix(key_from).each do |entry|
        keys << entry.key
      end
      keys.each do |key|
        if match(key)
          dest = if options[:mkdir]
            suffix = mkdir_relative(options[:mkdir], key) or next
            dest = File.join(File.expand_path(to), suffix)
          else
            dest = File.expand_path(to) + '/' + relative(key_from, key)
            dest = File.join(dest, File.basename(key)) if File.directory?(dest)
            dest
          end
          dir = File.dirname(dest)
          FileUtils.mkdir_p dir unless File.exist? dir
          fail "Destination path is not a directory: #{dir}" unless File.directory?(dir)
          if !options[:overwrite] && File.exist?(dest)
            $stderr.puts "Skipping #{dest} - already exists."
          else
            s3_to_local(bucket_from, key, dest, options)
          end
        end
      end
    else
      dest = if options[:mkdir]
        suffix = mkdir_relative(options[:mkdir], key_from) or
          fail("Error: The key '#{key_from}' does not match the --mkdir regular expression '#{options[:mkdir]}'")
        dest = File.join(File.expand_path(to), suffix)
        dir = File.dirname(dest)
        FileUtils.mkdir_p dir unless File.exist? dir
        dest
      else
        dest = File.expand_path(to)
        dest = File.join(dest, File.basename(from)) if File.directory?(dest)
      end
      if !options[:overwrite] && File.exist?(dest)
        $stderr.puts "Skipping #{dest} - already exists."
      else
        s3_to_local(bucket_from, key_from, dest, options)
      end
    end
  when :local_to_local
    if options[:include_regex].any? || options[:exclude_regex].any?
      fail "Include/exclude not supported on local-to-local copies"
    end
    if options[:recursive]
      FileUtils.cp_r from, to
      FileUtils.rm_r from if options[:move]
    else
      FileUtils.cp from, to
      FileUtils.rm from if options[:move]
    end
  end
end

S3CP.standard_exception_handling(options) do
  sources.each do |source|
    copy(source, destination, options)
  end
end

