require 'rubygems'
require 'extensions/kernel' if RUBY_VERSION =~ /1.8/
require 'right_aws'
require 'optparse'
require 'date'
require 'highline/import'

require 's3cp/utils'

# Parse arguments
options = {}
options[:date_format] = '%x %X'
options[:rows_per_page] = $terminal.output_rows if $stdout.isatty

op = OptionParser.new do |opts|
  opts.banner = "s3ls [path]"
  opts.separator ''

  opts.on("-l", "Long listing format") do
    options[:long_format] = true
  end

  opts.on("--date-format FORMAT", "Date format (see http://strfti.me/)") do |custom|
    options[:custom_params] = custom
  end

  opts.on("--verbose", "Verbose mode") do
    options[:verbose] = true
  end

  opts.on("--rows ROWS", "Rows per page") do |rows|
    options[:rows_per_page] = rows.to_i
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts op
    exit
  end
end
op.parse!(ARGV)

unless ARGV.size > 0
  puts op
  exit
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

@s3 = S3CP.connect()

rows = 0
@s3.interface.incrementally_list_bucket(@bucket, :prefix => @key) do |page|
  page[:contents].each do |entry|
    key = "s3://#{@bucket}/#{entry[:key]}"
    last_modified = DateTime.parse(entry[:last_modified])
    if options[:long_format]
      puts "#{last_modified.strftime(options[:date_format])} #{key}"
    else
      puts key
    end
    rows += 1
    if options[:rows_per_page] && (rows % options[:rows_per_page] == 0)
      begin
        print "Continue? (Y/n) "
        response = STDIN.gets.chomp.downcase
      end until response == 'n' || response == 'y' || response == ''
      exit if response == 'n'
    end
  end
end

