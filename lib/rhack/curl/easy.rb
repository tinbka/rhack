# encoding: utf-8
module Curl

  class Easy
    __init__
    attr_accessor :base
    
    def outdate!
      @outdated = true
    end
    
    def res
      if @res && !@outdated
        @res
      else 
        @outdated = false
        @res = Response(self)
      end
    end
    alias :response :res
    
    def req
      res.req
    end
    alias :request :req
    
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

    # <host>:<port>
    def url=(u)
      set :url, u
    end
    
    # <host>:<port>
    def proxy_url=(url)
      set :proxy, url
    end
    
    # <username>:<password>
    def userpwd=(value)
      set :userpwd, value
    end
    
    # <username>:<password>
    def proxypwd=(value)
      set :proxyuserpwd, value
    end
    
    def follow_location=(onoff)
      set :followlocation, onoff
    end
    
    def head=(onoff)
      if onoff
        set :httpget, false
        set :customrequest, nil
        set :nobody, true
      else
        set :nobody, false
      end
    end
    
    def get=(onoff)
      if onoff
        set :nobody, false
        set :customrequest, nil
        set :httpget, true
      else
        set :httpget, false
      end
    end
    
    def delete=(onoff)
      if onoff
        set :nobody, false
        set :httpget, false
        set :customrequest, 'DELETE'
      else
        set :customrequest, nil
      end
    end
    
  end
  
end