S3CP: Commands-line tools for Amazon S3 file manipulation
=============================================================

Just a few simple command-line utilities to list, copy, view S3 files, e.g.,  `s3cp`, `s3ls`, `s3cat`, `s3rm`, etc.

### Installing ###

Make sure you have Rubygems installed on your system then run:

    # gem install s3cp

### Building ###

If you want to hack on s3cp and build the gem yourself, you will need Bundler (http://gembundler.com/) installed.  Here is a typical development setup:

    # git clone git@github.com:aboisvert/s3cp.git
    # cd s3cp
    (... hack on s3cp ...)
    # bundle install
    # bundle exec rake gem
    # gem install s3cp-*.gem

### Examples ###

    export AWS_ACCESS_KEY_ID=...
    export AWS_SECRET_ACCESS_KEY=...

    s3ls s3://mybucket/path/to/some/files
    s3dir s3://mybucket/path/to/some/files
    s3cat s3://mybucket/path/to/some/file.txt
    s3cp local_file.bin s3://mybucket/some/path
    s3mod s3://mybucket/path/to/some/file.txt public-read
    s3stat s3://mybucket/path/to/some/file.txt

Use the `-h` option to learn about command-line options.

All commands support both `s3://bucket/path/to/file` and the legacy `bucket:path/to/file` syntax.

Commands are also TTY-aware;  when run in an interactive shell, their behavior will change.  For example, `s3cat` will launch your favorite `PAGER` or `less` (the default pager) whereas `s3ls` will display N items at a time, where N is the number of display lines on your terminal and pause between pages.

### Bash completion for S3 URLs ###

To install Bash completion for S3 URLs, add the following to ~/.bashrc:

    for cmd in [ s3cat s3cp s3dir s3ls s3mod s3rm s3stat ]; do
      complete -C s3cp_complete $cmd
    done

### Usage ###

    $ s3cp
    s3cp supports 4 copying use cases:
      1. Copy from local machine to S3
      2. Copy from S3 to local machine
      3. Copy from S3 to S3
      4. Copy from local machine to another path on local machine (for completeness)

    Local to S3:
      s3cp LOCAL_PATH S3_PATH

    S3 to Local:
      s3cp S3_PATH LOCAL_PATH

    S3 to S3:
      s3cp S3_PATH S3_PATH2

    Local to Local:
      s3cp LOCAL_PATH LOCAL_PATH2


    -r, --recursive                  Recursive mode

        --headers 'Header1: Header1Value','Header2: Header2Value'
                                     Headers to set on the item in S3.
        e.g.,
              HTTP headers: 'Content-Type: image/jpg'
               AMZ headers: 'x-amz-acl: public-read'

        --verbose                    Verbose mode
        --debug                      Debug mode
    -h, --help                       Show this message

---

    $ s3ls
    s3ls [path]

    -l                               Long listing format
        --date-format FORMAT         Date format (see http://strfti.me/)
        --verbose                    Verbose mode
        --rows ROWS                  Rows per page
    -h, --help                       Show this message

---

    $ s3cat
    s3cat [path]

        --debug                      Debug mode
        --tty                        TTY mode
    -h, --help                       Show this message

---

    $ s3mod
    s3mod [path] [permission]

    where [permission] is one of:

     * private
     * authenticated-read
     * public-read
     * public-read-write

    -h, --help                       Show this message

---

    $ s3rm
    s3rm [path]

    -r, --recursive                  Delete S3 keys matching provided prefix.
    -i, --include REGEX              Delete only S3 objects matching the following regular expression.
    -x, --exclude REGEX              Do not delete any S3 objects matching provided regular expression.
    -F, --fail-if-not-exist          Fail if no S3 object match provided key, prefix and/or regex
    -t, --test                       Only display matching keys; do not actually delete anything.
        --silent                     Do not display keys as they are deleted.
        --verbose                    Verbose mode
    -h, --help                       Show this message

### Dependencies ###

* highline `>=1.5.1`  (console/terminal size guessing)
* right_aws `=2.1.0`  (underlying Amazon S3 API)
* right_http_connection `=1.3.0` (required by `right_aws`)

### Target platform ###

* Ruby 1.8.7 / 1.9.2

### License ###

S3CP is is licensed under the terms of the Apache Software License v2.0.
<http://www.apache.org/licenses/LICENSE-2.0.html>

