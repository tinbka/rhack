# encoding: utf-8
$KCODE	= 'UTF-8' if RUBY_VERSION < "1.9"
require 'rmtools'
here = File.expand_path '..', __FILE__
require "rhack/version"

require File.join(here, 'curb_core.so')
require "rhack/js/johnson"

module RHACK
  mattr_reader :config, :redis, :useragents
  
  cfgfile = Dir['{config/,}rhack.yml'].first
  @@config = cfgfile ? YAML.load(IO.read(cfgfile)) : {}
  
  config.logger ||= {}
  config.logger[:out] &&= File.expand_path(config.logger[:out])
  L = RMTools::RMLogger.new(config.logger || {})
  # L is automatically included in any module under RHACK
  
  db = config.db || {}
  @@redis = nil
  
  if rcfg = db.redis
    begin
      require 'redis'
      @@redis = ::Redis.new(path: rcfg.socket, db: rcfg.db)
      redis.client.connect
    rescue Errno::ENOENT => errno
      rfcgfile = rcfg.configfilename || File.expand_path('config/redis.conf')
      cmd = %{redis-server "#{rcfgfile}"}
      msg = "#{errno.message}. Trying to run redis-server: `#{cmd}`"
      $stderr.puts msg
      L.log msg
      res = `#{cmd}`
      begin
        redis.client.connect
      rescue => err
        err.message = "Can't connect to redis using config @ #{rcfgfile}. #{err.message}"
        raise err
      end
    rescue LoadError => loaderr
      msg = "#{loaderr.message}. RHACK.redis will stay turned off"
      $stderr.puts msg
      L.log msg
    end
  end
  
  uas = config.useragents || {}
  if uas = uas.desktop.to_s and File.file? uas
    @@useragents = IO.read(uas)/"\n"
  else
    @@useragents = ['Mozilla/5.0 (Windows NT 6.1; WOW64; rv:14.0) Gecko/20100101 Firefox/14.0.1']
  end
  
  class Scout
    mattr_reader :cacert
    mattr_accessor :retry, :timeout
    
    scout = RHACK.config.scout || {}
    @@retry     = scout.retry.b || {}
    @@timeout = scout.timeout.b || 60
    @@cacert  = scout.cacert.b ? File.expand_path(scout.cacert) : File.expand_path('../../config/cacert.pem', __FILE__)
  end
  
end

module Curl
  # $Carier, $CarierThread, $CarierThreadIsJoined respectively
  mattr_reader :carier, :carier_thread, :joined
  L = RHACK::L
  
  @@carier = Curl::Multi.new
  carier.pipeline = true
  $Carier	||= carier
end

class Johnson::Runtime
  L = RHACK::L
end

# uhm, backward compatibility? more like historicity
HTTPAccessKit = RHACK

require "rhack/curl"
require "rhack/cookie"
require "rhack/scout"
require "rhack/scout_squad"
require "rhack/frame"
require "rhack/page"
if defined? Redis::Objects
  require "rhack/storage"
end
