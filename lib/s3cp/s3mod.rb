require 'rubygems'  
require 'right_aws'  
require 'optparse'
require 's3cp/utils'

op = OptionParser.new do |opts|
  opts.banner = "s3mod [path] [permission]"

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

def update_permissions(s3, bucket, key, permission)  
  puts "Setting #{permission} on s3://#{bucket}/#{key}"
  s3.interface.copy(bucket, key, bucket, key, :replace, {"x-amz-acl" => permission })  
end  

source  = ARGV[0]
permission = ARGV.last

LEGAL_MODS = %w{private authenticated-read public-read public-read-write}
raise "Permissions must be one of the following values: #{LEGAL_MODS}" unless LEGAL_MODS.include?(permission)

@s3 = S3CP.connect()
bucket,key = S3CP.bucket_and_key(source)
update_permissions(@s3, bucket, key, permission)  
