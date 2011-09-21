S3CP: Commands-line tools for Amazon S3 file manipulation
=============================================================

Just a few simple command-line utilities to list, copy, view S3 files, e.g.,  `s3cp`, `s3ls`, `s3cat`.

### Building ###

    # rake gem
    # gem install s3cp-0.1.0.gem

### Examples ###

    export AWS_ACCESS_KEY_ID=...
    export AWS_SECRET_ACCESS_KEY=...

    s3ls s3://mybucket/path/to/some/files
    s3cat s3://mybucket/path/to/some/file.txt
    s3cp local_file.bin s3://mybucket/some/path
    s3mod s3://mybucket/path/to/some/file.txt public-read

Use the `-h` option to learn about command-line options.

All commands support both `s3://bucket/path/to/file` and the legacy `bucket:path/to/file` syntax.

Commands are also TTY-aware;  when run in an interactive shell, their behavior will change.  For example, `s3cat` will launch your favorite `PAGER` or `less` (the default pager) whereas `s3ls` will display N items at a time, where N is the number of display lines on your terminal and pause between pages.

### Dependencies ###

* highline `>=1.5.1`  (console/terminal size guessing)
* right_aws `=2.1.0`  (underlying Amazon S3 API)
* right_http_connection `=1.3.0` (required by `right_aws`)

### Target platform ###

* Ruby 1.8.7 / 1.9.2

### License ###

S3CP is is licensed under the terms of the Apache Software License v2.0.
<http://www.apache.org/licenses/LICENSE-2.0.html>

