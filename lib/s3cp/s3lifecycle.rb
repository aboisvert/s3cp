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

require 's3cp/utils'

# Default options
options = { :verbose => false }

# Setup cli params
op = OptionParser.new do |opts|
  opts.banner = <<-BANNER
    s3lifecycle [COMMANDS] prefix
  BANNER
  opts.separator ''

  opts.on("--verbose", "Verbose mode") do
    options[:verbose] = true
  end

  opts.on("--name NAME", "Rule identifier optionally used in combination with --expire/glacier/enable/disable/remove") do |name|
    options[:name] = name
  end

  opts.on("--expire DAYS_OR_DATE", "Expire object(s) after given number of days or specific date (YYYY-MM-DD)") do |time|
    options[:expire] = S3CP.parse_days_or_date(time)
  end

  opts.on("--glacier DAYS_OR_DATE", "Transition objects to Glacier after given number of days or specific date (YYYY-MM-DD)") do |time|
    options[:glacier] = S3CP.parse_days_or_date(time)
  end

  opts.on("--enable", "Enable rule(s) for expiration/glacier object transition") do
    options[:enable] = true
  end

  opts.on("--disable", "Disable rule(s) for expiration/glacier object transition") do
    options[:disable] = true
  end

  opts.on("--delete", "Delete rule(s) for expiration/glacier object transition") do
    options[:delete] = true
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts op
    exit
  end
end

p options.inspect if options[:verbose]

op.parse!(ARGV)
paths = ARGV

if ARGV.size == 0
  puts op
  exit
end

def time_or_date_str(msg, t)
  if t.is_a?(Fixnum) || t.to_s =~ /^\d+$/
    "%s after %d days" % [msg, t.to_i]
  else
    "%s on %s" % [msg, t]
  end
end

def rule_to_str(r)
  if r.expiration_time
    [ r.prefix || "[root]", r.id, r.status, time_or_date_str("Expire", r.expiration_time)]
  elsif r.glacier_transition_time
    [ r.prefix || "[root]", r.id, r.status, time_or_date_str("Glacier", r.glacier_transition_time)]
  else
    [ r.prefix || "[root]", r.id, r.status, "???"]
  end
end
S3CP.standard_exception_handling(options) do

  S3CP.load_config()
  @s3 = S3CP.connect()

  paths.each do |path|
    bucket,key = S3CP.bucket_and_key(path)
    fail "Invalid bucket/key: #{path}" unless key

    case

      when options[:expire]
        @s3.buckets[bucket].lifecycle_configuration.update do
          rule_options = {}
          rule_options[:id] = options[:name] if options[:name]
          rule_options[:expiration_time] = S3CP.parse_days_or_date(options[:expire])
          add_rule(key, rule_options)
        end

      when options[:glacier]
        @s3.buckets[bucket].lifecycle_configuration.update do
          rule_options = {}
          rule_options[:id] = options[:name] if options[:name]
          rule_options[:glacier_transition_time] = S3CP.parse_days_or_date(options[:glacier])
          add_rule(key, rule_options)
        end

      when options[:enable]
        success = false
        @s3.buckets[bucket].lifecycle_configuration.update do
          self.rules.each do |r|
            if (r.prefix == key) || (r.id == options[:name])
              r.enable!
              puts "Enabled rule: "
              puts S3CP.tableify([rule_to_str(r)])
              success = true
            end
          end
        end
        fail "Rule or prefix not found" unless success

      when options[:disable]
        success = false
        @s3.buckets[bucket].lifecycle_configuration.update do
          self.rules.each do |r|
            if (r.prefix == key) || (r.id == options[:name])
              r.disabled!
              puts "Disabled rule: "
              puts S3CP.tableify([rule_to_str(r)])
              success = true
            end
          end
        end
        fail "Rule or prefix not found" unless success

      when options[:delete]
        success = false
        @s3.buckets[bucket].lifecycle_configuration.update do
          self.rules.each do |r|
            if (r.prefix == key) || (r.id == options[:name])
              remove_rule(r)
              puts "Deleted rule: "
              puts S3CP.tableify([rule_to_str(r)])
              success = true
            end
          end
        end
        fail "Rule or prefix not found" unless success

      else
        rules = @s3.buckets[bucket].lifecycle_configuration.rules.to_a
        if rules.empty?
          puts "#{bucket} - no lifecycle rules"
        else
          puts "#{bucket} - lifecycle rules:"
          begin
            puts S3CP.tableify(rules.map { |r| rule_to_str(r) })
          rescue => e
            puts rules.inspect
            raise e
          end
        end
    end
  end
end