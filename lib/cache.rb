# encoding: utf-8
module HTTPAccessKit

  class Cache < ActiveRecord::Base
    declare CacheTable do |t|
        t.integer :url_hash
        t.string :url
        t.string :path
        t.string :date
        t.string :ext
        t.timestamps
    end if DB
    RAMCache = {}
    
    def self.clean(time=7.days)
      destroy_all("created_at < '#{time.ago}'").each {|c|
        FileUtils.remove c.path if c.path and File.file?(c.path)}
    end
    CacheTTL and clean CacheTTL
    
    def self.save(url, data, cache_data=true)
      new(url, data).save
      RAMCache[url.href] = data if cache_data
    end
    
    def self.load(url, cache_data=true)
      if data = RAMCache[url.href]
        data
      elsif file = first(:select => 'date, path', :conditions => {:url_hash => url.href.hash})
        RAMCache[url.href] = read(file.path) if cache_data
        file
      end
    end
    
    def initialize(url, data)
      t = Time.now
      path = "#{CacheDir}/#{t.to_i}-#{File.split(url.path)[1]}"
      rw path, data
      super :url => url.href, :url_hash => url.href.hash, :date => t.httpdate, :path => path, :ext => url.ext
    end
    
  end
  
end