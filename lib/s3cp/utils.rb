module S3CP
  extend self

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
end

