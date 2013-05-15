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
      each {|s| return L.warn "failed to update scout loaded? with url: #{s.http.url}" if s.loaded?} if !forced
      each {|s| s.update uri}
    end
    
    def untargeted
      first.root == 'http://'
    end
      
    def rand
      raise PickError if !b
      # to_a because reject returns object of this class
      if scout = to_a.rand {|_|!_.loaded?}; scout
      else # Curl should run here, otherwise `next'/`rand'-recursion will cause stack overflow
        unless Curl.status
          L.log "Curl must run in order to use ScoutSquad#rand; setting Carier Thread"
          Curl.execute
          #raise "Curl must run in order to use ScoutSquad#rand"
        end
        #Curl.wait
        loop {
          sleep 1
          break if Curl.carier.reqs.size < size
        }
        self.rand 
      end 
    end
      
    def next
      raise PickError if !b
      if scout = find {|_|!_.loaded?}; scout
      else # Curl should run here, otherwise `next'/`rand'-recursion will cause stack overflow
        unless Curl.status
          L.log "Curl must run in order to use ScoutSquad#next; setting Carier Thread"
          Curl.execute :unless_allready
          #raise "Curl must run in order to use ScoutSquad#next"
        end
        #Curl.wait
        loop {
          sleep 1
          break if Curl.carier.reqs.size < size
        }
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