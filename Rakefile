# encoding: utf-8
#!/usr/bin/env ruby
require "bundler/gem_tasks"

namespace :redis do
  desc "Create redis.conf out of redis.yml or config/redis.yml"
  
  task :config do
    mask = '{config/,}{redis,rhack}.yml'
    src = '/home/shinku/redis.yml'#FileList[mask].first
    unless src
      puts "Source yml file is not found, searched mask: #{mask}"
      exit
    end
    require 'active_support'
    require 'rmtools'
    rcfg = YAML.load(IO.read src)
    if src['rhack']
      rcfg = rcfg.db.redis
    end
    
    dest = rcfg.configfilename || File.expand_path('config/redis.conf')
    if uptodate? dest, [src]
      puts dest+' is allready up to date'
    else
      config = {}
      config.daemonize = rcfg.daemonize || 'yes'
      config.pidfile = rcfg.pidfile || File.expand_path('tmp/pids/redis.pid')
      config.port = rcfg.port || 0
      if rcfg.port.to_i == 0
        config.unixsocket = rcfg.socket || File.expand_path('tmp/sockets/redis.sock')
        config.unixsocketperm = rcfg.socketperm || 775
      end
      config.logfile = rcfg.logfile || File.expand_path('log/redis.log')
      config.loglevel = rcfg.loglevel || 'notice'
      config.dir = rcfg.dir || './'
      config.dbfilename = rcfg.dbfilename || File.expand_path('db/dump.rdb')
      config.databases = rcfg.databases || 1

      config = config.to_a.joins(' ') + (rcfg.save || ['900 1', '300 10', '60 10000']).map {|i| "save #{i}"}

      RMTools::rw dest, config*"\n"
      puts "Written configuration to #{dest}"
    end
  end
end
