$stderr.puts 'require "rhack_in" is deprecated. Just require "rhack" and use it\'s classes being modularized!'
$stderr.puts "called from #{caller(1).find {|line| line !~ /dependencies.rb/}}"
require 'rhack'