# Copyright (C) 2010-2012 Alex Boisvert and Bizo Inc. / All rights reserved.
#
# Licensed to the Apache Software Foundation (ASF) under one or more contributor
# license agreements.  See the NOTICE file  distributed with this work for
# additional information regarding copyright ownership.  The ASF licenses this
# file to you under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License.  You may obtain a copy of
# the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.

lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require "s3cp/version"

Gem::Specification.new do |s|
  s.name        = "s3cp"
  s.version     = S3CP::VERSION
  s.platform    = Gem::Platform::RUBY

  s.authors     = ["Alex Boisvert"]
  s.email       = ["alex.boisvert@gmail.com"]

  s.summary     = "Amazon S3 tools to, e.g., list, copy, delete S3 files"

  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency("extensions", ["~> 0.6"])
  s.add_dependency("highline", ["~> 1.5.1"])
  s.add_dependency("aws-sdk", ["~> 1.6.3"])
  s.add_dependency("progressbar", ["~> 0.10.0"])

  s.add_development_dependency("rspec", ["~> 2.5.0"])
  s.add_development_dependency("rake", ["~> 0.8.7"])

  s.files        = Dir.glob("lib/**/*") +
                   %w{History.txt README.md} +
                   Dir.glob("bin/*")

  s.executables << 's3cat'
  s.executables << 's3cp'
  s.executables << 's3cp_complete'
  s.executables << 's3dir'
  s.executables << 's3du'
  s.executables << 's3ls'
  s.executables << 's3mod'
  s.executables << 's3mv'
  s.executables << 's3rm'
  s.executables << 's3stat'
  s.executables << 's3up'

  s.extra_rdoc_files = ['README.md', 'History.txt']

  s.require_path = 'lib'
end

