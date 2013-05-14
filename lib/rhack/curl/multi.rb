# encoding: utf-8
module Curl
  
  class Multi
    if method_defined? :requests
      alias :reqs :requests
    end
    
    def sheduled
      0 < running and running <= reqs.size
    end
    
    def inspect
      rsize = reqs.size
      "<#Carier #{rsize} #{rsize == 1 ? 'unit' : 'units'}, #{running} executing>"
    end
    
    
    # Used for Curl.reset_carier!
    def clear!
      reqs.each {|k| remove k rescue()}
    end
    
    # Emergency debug methods, not used inside a framework
    def drop
      while running > 0 do perform rescue() end
      Curl.recall
    end
    
    def drop!
      drop
      Curl.reset_carier! if reqs.size + running > 0
    end
    
  end
  
end