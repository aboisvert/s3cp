S3CP: Commands-line tools for Amazon S3 fiel manipulation
=============================================================

Just a few simple command-line utilities to list, copy, view S3 files.

e.g.  s3cp, s3ls, s3cat

### Building ###

    # rake gem
    # gem install s3cp-0.1.0.gem

### Examples ###

    export AWS_ACCESS_KEY_ID=...
    export AWS_SECRET_ACCESS_KEY=...

    s3ls s3://mybucket/path/to/some/files
    s3cat s3://mybucket/path/to/some/file.txt
    s3cp local_file.bin s3://mybucket/some/path

Use -h option to learn about command-line options.

### Dependencies ###

* highline >= 1.5.1  (console/terminal size guessing)
* right_aws = 2.1.0  (underlying Amazon S3 API)
* right_http_connection = 1.30 (required by right_aws)

### Target platform ###

* Ruby 1.8.7 / 1.9.2

### License ###

S3CP is is licensed under the terms of the Apache Software License v2.0.
<http://www.apache.org/licenses/LICENSE-2.0.html>

