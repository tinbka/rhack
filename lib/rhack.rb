# encoding: utf-8
$KCODE	= 'UTF-8' if RUBY_VERSION < "1.9"
require 'rmtools_dev' unless defined? RMTools
requrie 'cgi'
here = File.expand_path File.dirname __FILE__
require File.join(here, 'curb_core.so')
require 'active_record'
Dir.glob("#{here}/extensions/**.rb") { |f| require f }

require "#{here}/init" unless defined? RHACK
RHACK::VERSION = IO.read(File.join here, '..', 'Rakefile').match(/RHACK_VERSION = '(.+?)'/)[1]

require "#{here}/curl-global"
require "#{here}/scout"
require "#{here}/frame"
require "#{here}/words"
require "#{here}/cache" if defined? RHACK::CacheDir
