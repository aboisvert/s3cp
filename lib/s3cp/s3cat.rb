require 'rubygems'
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

# if TTY, store contents to file
if options[:tty]
  file = Tempfile.new('s3cat')
  out = File.new(file.path, File::CREAT|File::RDWR)
else
  out = STDOUT
end

# write contents to file or STDOUT
begin
  @s3.get(@bucket, @prefix) do |chunk|
    if file
      out.write(chunk)
    else
      STDOUT.print(chunk)
    end
  end
ensure
  out.close() if file
end

# if TTY, use PAGER to display the file
if file
  exec "#{ENV['PAGER'] || 'less'} #{file.path}"
  file.delete()
end

