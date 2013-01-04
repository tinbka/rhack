# encoding: utf-8
module Curl

  class Easy
    __init__
    attr_accessor :base
    
    def res
      Response(self)
    end
    alias response res
    
    def req
      res.req
    end
    alias request req
    
    def host
      url.parse(:uri).root
    end
    
    def path=(href)
      self.url = host+href.parse(:uri).fullpath
    end
    
    def retry!
      @base.retry!
    end
    
    # curb changed getters interface, so i get some shortcuts from curb/lib/curl/easy.rb
    def set(opt,val)
      if opt.is_a?(Symbol)
        setopt(sym2curl(opt), val)
      else
        setopt(opt.to_i, val)
      end
    end
    
    def sym2curl(opt)
      Curl.const_get("CURLOPT_#{opt.to_s.upcase}")
    end
    
    def interface=(value)
      set :interface, value
    end

    def url=(u)
      set :url, u
    end
    
    def proxy_url=(url)
      set :proxy, url
    end
    
    def userpwd=(value)
      set :userpwd, value
    end
    
    def proxypwd=(value)
      set :proxyuserpwd, value
    end
    
    def follow_location=(onoff)
      set :followlocation, onoff
    end
    
    def head=(onoff)
      set :nobody, !!onoff
    end
    
    def get=(onoff)
      set :httpget, !!onoff
    end
    
  end
  
  class PostField
    
    def to_s
      raise "Cannot convert unnamed field to string" if !name
      display_content = if (cp = content_proc)
          cp.inspect 
        elsif (c = content)
          "#{c[0...20].inspect}#{"… (#{c.size.bytes})" if c.size > 20}"
        elsif (ln = local_name)
          File.new(ln).inspect
        end
      "#{name}=#{display_content}"
    end
    
  end
  
  class Multi
    if method_defined? :requests
      alias :reqs :requests
    end
    
    def reset
      reqs.each {|k| remove k rescue()}
      $Carier = Multi.new
      $Carier.pipeline = true
#      GC.start
    end
    
    def drop
      while running > 0 do perform rescue() end
      Curl.recall
    end
    
    def drop!
      drop
      reset if reqs.size + running > 0
    end
    
    def sheduled
      0 < running and running <= reqs.size
    end
    
    def inspect
      "<#Carier #{'unit'.x reqs.size}, #{running} executing>"
    end
    
  end
  
end