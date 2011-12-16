require 'rubygems'
require 'extensions/kernel' if RUBY_VERSION =~ /1.8/
require 'right_aws'
require 'optparse'
require 'date'
require 'highline/import'

require 's3cp/utils'

# Parse arguments
options = {}
options[:recursive] = false
options[:include_regex] = nil
options[:exclude_regex] = nil
options[:test]   = false
options[:silent] = false
options[:fail_if_not_exist] = false

op = OptionParser.new do |opts|
  opts.banner = "s3rm [path]"
  opts.separator ''

  opts.on("-r", "--recursive", "Delete S3 keys matching provided prefix.") do
    options[:recursive] = true
  end

  opts.on("-i REGEX", "--include REGEX", "Delete only S3 objects matching the following regular expression.") do |regex|
    options[:include_regex] = regex
  end

  opts.on("-x REGEX", "--exclude REGEX", "Do not delete any S3 objects matching provided regular expression.") do |regex|
    options[:exclude_regex] = regex
  end

  opts.on("-F", "--fail-if-not-exist", "Fail if no S3 object match provided key, prefix and/or regex") do
    options[:fail_if_not_exist] = true
  end

  opts.on("-t", "--test", "Only display matching keys; do not actually delete anything.") do
    options[:test] = true
  end

  opts.on("--silent", "Do not display keys as they are deleted.") do
    options[:silent] = true
  end

  opts.on("--verbose", "Verbose mode") do
    options[:verbose] = true
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts op
    exit
  end
end
op.parse!(ARGV)

unless ARGV.size > 0
  puts op
  exit(1)
end

if options[:include_regex] && !options[:recursive]
  puts "-i (--include regex) option requires -r (recursive) option."
  exit(1)
end

if options[:exclude_regex] && !options[:recursive]
  puts "-x (--exclude regex) option requires -r (recursive) option."
  exit(1)
end

url = ARGV[0]

if options[:verbose]
  puts "URL: #{url}"
  puts "Options: #{options.inspect}"
end

@bucket, @key = S3CP.bucket_and_key(url)
fail "Your URL looks funny, doesn't it?" unless @bucket

if options[:verbose]
  puts "bucket #{@bucket}"
  puts "key #{@key}"
end

include_regex = options[:include_regex] ? Regexp.new(options[:include_regex]) : nil
exclude_regex = options[:exclude_regex] ? Regexp.new(options[:exclude_regex]) : nil

@s3 = S3CP.connect()

if options[:recursive]
  matching_keys = []

  @s3.interface.incrementally_list_bucket(@bucket, :prefix => @key) do |page|
    page[:contents].each do |entry|
      key = "s3://#{@bucket}/#{entry[:key]}"

      matching = true
      matching = false if include_regex && !include_regex.match(entry[:key])
      matching = false if exclude_regex && exclude_regex.match(entry[:key])

      puts "#{key} => #{matching}" if options[:verbose]

      if matching
        matching_keys << entry[:key]
        puts key unless options[:silent] || options[:verbose]
      end
    end
  end

  if options[:fail_if_not_exist] && matching_keys.length == 0
    puts "No matching keys."
    exit(1)
  end

  errors = []
  errors = @s3.interface.delete_multiple(@bucket, matching_keys) unless options[:test]

  if errors.length > 0
    puts "Errors during deletion:"
    errors.each do |error|
      puts "#{error[:key]} #{error[:code]} #{error[:message]}"
    end
    exit(1)
  end
else
  # delete a single file; check if it exists
  if options[:fail_if_not_exist] && @s3.interface.head(@bucket, @key) == nil
    key = "s3://#{@bucket}/#{@key}"
    puts "#{key} does not exist."
    exit(1)
  end

  begin
    @s3.interface.delete(@bucket, @key) unless options[:test]
  rescue => e
    puts e.to_s
    raise e unless e.to_s =~ /Not Found/
  end
end
