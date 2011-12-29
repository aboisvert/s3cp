require 'rubygems'
require 'extensions/kernel' if RUBY_VERSION =~ /1.8/
require 'right_aws'
require 'optparse'
require 'date'
require 'highline/import'
require 'tempfile'

require 's3cp/utils'

# Parse arguments
options = {}
options[:tty] = $stdout.isatty

op = OptionParser.new do |opts|
  opts.banner = "s3cat [path]"
  opts.separator ''

  opts.on("--debug", "Debug mode") do
    options[:debug] = true
  end

  opts.on("--tty", "TTY mode") do |tty|
    options[:tty] = tty
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

@bucket, @prefix = S3CP.bucket_and_key(url)
fail "Your URL looks funny, doesn't it?" unless @bucket

@s3 = S3CP.connect().interface

if options[:tty]
  # store contents to file to display with PAGER
  file = Tempfile.new('s3cat')
  out = File.new(file.path, "wb")
  begin
    @s3.get(@bucket, @prefix) do |chunk|
      out.write(chunk)
    end
  ensure
    out.close()
  end
  exec "#{ENV['PAGER'] || 'less'} #{file.path}"
  file.delete()
else
  @s3.get(@bucket, @prefix) do |chunk|
    STDOUT.print(chunk)
  end
end

