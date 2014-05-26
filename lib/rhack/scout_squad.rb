module RHACK

  class PickError < IndexError
    def initialize
      super "can't get scout from empty squad" end
  end

  class ScoutSquad < Array
    __init__
    
    def initialize(*args)
      raise ArgumentError, "can't create empty squad" if (num = args.pop) < 1
      proxies = nil
      super []
      if args[0].is Scout
        s = args[0]
      else
        if !args[0].is String
          args.unshift ''
          if (opts = args[-1]).is Hash and (opts[:cp] || opts[:ck]).is Hash
            L.warn "it's useless to setup cookies for untargeted squad!"
          end
        end
        if args[1] and args[1][0].is Array
          proxies = args[1]
          args[1] = proxies.shift
        end
        self[0] = s = Scout(*args)
        num -=1
      end
      num.times {|i| 
        self << Scout(s.root+s.path, (proxies ? proxies[i] : s.proxy), s.ua, s.refforge, :ck => s.main_cks, :raise => s.raise_err, :timeout => s.timeout, :retry => s.retry)
      }
    end
    
    def update uri, forced=nil
      each {|s| return L.warn "failed to update loaded scout with url: #{s.http.url}" if s.loaded?} if !forced
      each {|s| s.update uri}
    end
    
    def untargeted
      first.root == 'http://'
    end
    
    def wait_for_available
      L.debug {"Curl.carier_thread = #{Curl.carier_thread}; Thread.current = #{Thread.current}"}
      Curl.execute :unless_already
      L.debug {"Curl.carier_thread = #{Curl.carier_thread}; Thread.current = #{Thread.current}"}
      # Carier.requests освобождаются ещё до колбека,
      # но колбеки выполняются последовательно,
      # поэтому здесь мы можем усыплять тред,
      # но только если это не тред самого Carier
      if Curl.carier_thread == Thread.current
        Curl.wait # runs Multi#perform
      else
        sleep 1
      end
    end
      
    def rand
      raise PickError if !b
      # to_a because Array#reject returns object of this class
      if scout = to_a.rand_by_available?
        L.debug {"randomly picked an available scout##{scout.object_id}"}
        scout
      else
        wait_for_available
        self.rand 
      end 
    end
      
    def next
      raise PickError if !b
      if scout = to_a.find_available?
        L.debug {"picked the next available scout##{scout.object_id}"}
        scout
      else
        wait_for_available
        self.next
      end 
    end
    
    def to_s
      str = '<#ScoutSquad @ '
      if b
        if first.webproxy
          str << "#{first.proxy} ~ "
        elsif first.proxy
          str << first.proxy*':'+" ~ " 
        end
        str << "#{untargeted ? "no target" : first.root} "
      end
      str << "x#{size}>"
    end
    alias :inspect :to_s
    
  end
  
end