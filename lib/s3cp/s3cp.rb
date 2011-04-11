require 'rubygems'
require 'right_aws'
require 'optparse'
require 'date'
require 'highline/import'

# Parse arguments
options = {}
options[:verbose] = true if $stdout.isatty

op = OptionParser.new do |opts|
  opts.banner = "s3cp [path]"
  opts.separator ''

  opts.on("--verbose", "Verbose mode") do
    options[:verbose] = true
  end

  opts.on("--debug", "Debug mode") do
    options[:debug] = true
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

if options[:debug]
  puts "URL: #{url}"
  puts "Options: \n#{options.inspect}"
end

fail "Your URL looks funny, doesn't it?" unless url =~ /s3:\/\/([^\/]*)\/?(.*)/
@bucket = $1
@prefix = $2

@s3 = S3CP.connect()

rows = 0
@s3.interface.incrementally_list_bucket(@bucket, :prefix => @prefix) do |page|
  page[:contents].each do |entry|
    key = entry[:key]
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
      break if response == 'n'
    end
  end
end

