# encoding: utf-8
module HTTPAccessKit
  include RMTools
  extend RMTools
  
  Dir.chdir ENV['APP_ROOT'] if ENV['APP_ROOT']
  
  CONFIG = if defined? Rails
    YAML.load(read('config/rhack.yml') || '') || {}
  else
    YAML.load(read(%W(config/rhack.yml rhack.yml #{File.join(ENV['HOME'], 'rhack.yml')})) || '') || {}
  end

  UAS = if File.file?(uas = CONFIG['ua file'] || File.join(ENV['HOME'], 'ua.txt'))
           IO.read(uas)/"\n"
  else   ['Mozilla/5.0 (Windows NT 6.1; WOW64; rv:14.0) Gecko/20100101 Firefox/14.0.1'] end
  
  L = RMLogger.new(CONFIG.logger || {})
  
  db_config = if defined? Rails
    YAML.load(read('config/database.yml'))[ENV["RAILS_ENV"]]
  else
    CONFIG.db || File.join(ENV['HOME'], 'db.yml')
  end
  begin
    DB = ActiveRecord::Base.establish_connection_with db_config
  rescue LoadError
    DB = nil
  end
  if DB and !(CONFIG.cache and CONFIG.cache.enabled == false)
    cache	      = CONFIG.cache || {}
    CacheDir	  = cache.dir || File.join(File.dirname(__FILE__), 'cache')
    CacheTable	= (cache.table || :rhack_cache).to_sym
    CacheTTL	  = cache.clean ? eval(cache.clean).b : nil
  end
    
  RETRY     = CONFIG['scout retry'] || {}
  
  $uas	  ||= UAS
  $Carier	||= Curl::Multi.new
  $Carier.pipeline = true
  
  def self.update
    each_child {|c| c.class_eval "include HTTPAccessKit; extend HTTPAccessKit" if !c.in c.children}
  end
end

module Curl; extend HTTPAccessKit end
RHACK = HTTPAccessKit
