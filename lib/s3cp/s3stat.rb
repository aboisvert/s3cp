require 'rubygems'
require 'extensions/kernel' if RUBY_VERSION =~ /1.8/
require 'right_aws'
require 'optparse'
require 's3cp/utils'

op = OptionParser.new do |opts|
  opts.banner = "s3stat [path]"

  opts.on_tail("-h", "--help", "Show this message") do
    puts op
    exit
  end
end

op.parse!(ARGV)

if ARGV.size < 1
  puts op
  exit
end

source  = ARGV[0]
permission = ARGV.last

@s3 = S3CP.connect()

def get_metadata(bucket, key)
  metadata = @s3.interface.head(bucket, key)
  metadata.sort.each do |k,v|
    puts "#{"%20s" % k} #{v}"
  end
end

bucket,key = S3CP.bucket_and_key(source)
get_metadata(bucket, key)

