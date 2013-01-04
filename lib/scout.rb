# encoding: utf-8
module Curl
  
  def ITT
    res = nil
    HTTPAccessKit::Scout('file://').loadGet(__FILE__) {|c| res = yield}
    loop {if res then break res else sleep 0.01 end}
  end
  module_function :ITT
  
  class Response
    __init__
    attr_reader :header, :code, :body, :hash, :timestamp, :time, :req, :date, :error
    
    def to_s
      str = '<#'
      if @error
        str << "#{@error[0].self_name}: #{@error[1]}"
      else
        str << (@header[/\d{3}/] == @code.to_s ? @header : "#{@header[/\S+/]} #{@code}") if @header
        if @hash.location
          str << ' '+@req.url if $panic
          str << ' -> '+@hash.location 
        end
        str << " (#{@body ? @body.size.bytes : 'No'} Body)"
        str << " [#{@timestamp}]" if @timestamp
      end
      str << '>'
    end
    alias :inspect :to_s
    
    def initialize(easy)
      @hash = {}
      @timestamp = @date = @header = nil
      if easy.base.error
        @error = easy.base.error
      else
        if headers = easy.header_str || easy.base.headers
          headers /= "\r\n"
          @header = headers.shift
          headers.each {|h|
            h /= ': '
            if h[0]
              h[0].downcase!
              if h[0] == 'set-cookie'
                (@hash.cookies ||= []) << h[1]
              else
                @hash[h[0]] = h[1]
              end
            end
          }
          @timestamp = if @hash.date
              begin
                @date = @hash.date.to_time
              rescue => e
                (@date = Time.now).strftime("%H:%M:%S")
                L < "Error #{e.class}:#{e.message} with @hash.date = #{@hash.date.inspect}"
              end
              @hash.date[/\d\d:\d\d:\d\d/]
            else
              (@date = Time.now).strftime("%H:%M:%S")
            end
        end
        @code	= easy.response_code
        @body	= easy.body_str 
        @time	= easy.total_time
      end
      
      @req = {}
      @req.url	        = easy.last_effective_url
      @req.headers	= easy.headers
      if range = easy.headers.Range and range[/(\d+)-(\d+)/]
        @req.range   = $1.to_i .. $2.to_i
      end
      if easy.base and @req.meth = easy.base.last_method and @req.meth == :post
        @req.body	  = easy.post_body
        @req.mp	    = easy.multipart_form_post?
      end
    end
    
    def is(klass)
      if @error
        klass == Array || klass = Curl::Response
      else
        klass == Curl::Response
      end
    end
  
    def [](key_or_index)
      @error ? @error[key_or_index] : @hash[key_or_index.downcase]
    end
    
    alias :headers :hash
  end
  
end

module HTTPAccessKit

  class Cookie
    __init__
    
    def initialize(*args)
      if args[1].is Scout
        str, scout = *args
        ck = str//;\s*/
        ck[1..-1].each {|par|
          a = par/'='
          case a[0].downcase
            when 'path'; @path = (a[1] == '/') ? // : /^#{Regexp.escape a[1]}/
            when 'domain'; @domain = /(^|\.)#{Regexp.escape a[1].sub(/^./, '')}$/
            when 'expires'; @expires = a[1].to_time
          end
        }
        @name, @value = ck[0].split('=', 2)
        #@value.gsub!(/^['"]|['"]$/, '')
        #L.debug args if !@domain
        (scout.cookies[scout.uri.host] ||= {})[@name] = self
      else
        @name, cookie = args[0]
        case cookie
          when Array; @value, @path, @domain = cookie
          when Hash; @value, @path, @domain = cookie.value, cookie.path, cookie.domain
          else @value = args[1].to_s
        end
      end
      @path ||= //
      @domain ||= //
      @string = "#{@name}=#{@value}; "
    end
    
    def use(str, uri)
      if !@expires or @expires > Time.now
        str << @string if uri.path[@path] and !uri.root || uri.host[@domain]
      else
        :expired
      end
    end
      
    def to_s; @value end
    def inspect; @value.inspect end
    
  end

  class Scout
    __init__
    attr_accessor	:timeout, :raise_err, :retry
    attr_accessor	:path, :root, :sld, :proxy
    attr_reader	    :uri
    attr_reader	    :webproxy, :last_method, :proxystr, :headers, :body, :http, :error
    attr_reader	    :cookies, :ua, :refforge, :cookieStore, :cookieProc
    
    DefaultHeader = {
        "Expect"	              => "",
        "Keep-Alive"	        => "300",
        "Accept-Charset"	=> "windows-1251,utf-8;q=0.7,*;q=0.7",
        "Accept-Language"	=> "ru,en-us;q=0.7,en;q=0.3",
        "Connection"	        => "keep-alive"
    }
    
    class ProxyError < ArgumentError
      def initialize proxy
        super "incorrect proxy: %s class %s, must be an Array
            proxy format: ['127.0.0.1', '80'], [2130706433, 80], ['someproxy.com', :WebproxyModule]"%[proxy.inspect, proxy.class]
      end
    end
    @@retry = RETRY
    
    def initialize(*argv)
      uri, proxy, @ua, @refforge, opts = argv.get_opts ['http://', nil, :rand, 1]
      raise ProxyError, proxy if proxy and (!webproxy && !proxy.is(Array) or webproxy && !proxy.is(String))
      'http://' >> uri if uri !~ /^\w+:\/\//
      if proxy
        if proxy[1] and proxy[1].to_i == 0
          @webproxy	= eval("WebProxy::#{proxy[1]}")
          @proxy	    = proxy[0].parse(:uri).root
        else 
          proxy[0]	  = proxy[0].to_ip if proxy[0].is Integer
          @proxy	  = proxy
        end
      end
      @cookies    	= {}
      @body       	= {}
      @num    	    = []
      @cookieProc	= opts[:cp] || opts[:ck]
      @raise_err   	= opts[:raise] # no way to use @raise id, it makes any 'raise' call here fail
      @engine     	= opts[:engine]
      @timeout    	= opts[:timeout] || $CurlDefaultTimeout || 60
      @post_proc	= @get_proc = @head_proc = Proc::NULL
      update uri
      @retry = opts[:retry] || {}
      @retry = {@uri.host => @retry} if @retry.is Array
    end
    
    def update(uri)
      if !uri[/^\w+:\/\//]
        '/' >> uri if uri[0,1] != '/'
        @uri = uri.parse:uri
        return                       
      end
      @uri = uri.parse:uri
      return if @uri.root == @root
      @root	= @uri.root
      @sld	  = @root[/[\w-]+\.[a-z]+$/]
      @path	= @uri.fullpath
      if @http
        @http.url = @webproxy ? @proxy : @root
      else
        @http = Curl::Easy(@webproxy ? @proxy : @root)
        @http.base = self       
      end
      if @proxy
        @http.proxy_url = @proxy*':' if !@webproxy
        @proxystr = @webproxy ? @proxy[0] : @http.proxy_url
      else @proxystr = 'localhost' 
      end
      if @cookieProc.is Hash
        self.main_cks = @cookieProc
        @cookieProc = true    
      end
      self
    end
    
    def to_s
      str = "<##{self.class.self_name} @ "
      if @webproxy
        str << "#{@proxy} ~ "
      elsif @proxy
        str << @proxy*':'+" ~ " 
      end
      str << @root+'>'
    end
    alias :inspect :to_s
    
    def update_res
      @outdated = false
      @res = @http.res
      @headers = nil
      @res
    end
    
    def res
      if @res && !@outdated
             @res
      else update_res end
    end
    
    def req; res.req   end
    
    def dump
      str = "IP: #{@proxystr}\nRequest: "
      str << ({"Action"=>@root+@path} + @http.headers).dump+@body.dump+"Response: #{res}"
      str << "\nReady" if @ready
      str
    end
  
    def fix(path)
      path = path.tr ' ', '+'
      path = expand path if path =~ /^\./
      if update(path) or @uri.root
        path = @webproxy.encode(path) if @webproxy
      else
        path = @webproxy.encode(@root+path) if @webproxy
      end
      path
    end
    
    def expand(uri)
      if !@webproxy || @http.last_effective_url
        path = (@http.last_effective_url ? @http.last_effective_url.parse(:uri) : @uri).path
        return uri.sub(/^(\.\.?\/)?/, File.split(uri =~ /^\.\./ ? File.split(path)[0] : path)[0])
      end
      uri
    end

    def mkBody(params, multipart=nil)
      if multipart
        @http.multipart_post_body = params.map {|k, v|
          v = v.call if v.is Proc
          if k =~ /^f:/
            Curl::PostField.file(k[2..-1], "application/octet-stream", 
                                     "#{randstr(16, :hex)}.jpg", v+randstr )
          elsif k =~ /^p:/
            Curl::PostField.file(k[2..-1], "application/octet-stream", 
                                     File.basename(f), read(v)                   )
          else
            Curl::PostField.content(k.to_s, v.to_s)
          end
        }
      else
        @http.post_body = params.urlencode
      end
    end
    
    def mkHeader(uri)
      header = DefaultHeader.dup
      if @cookieProc
        cookies = ''
        main_cks.each {|k, v| main_cks.delete k if v.use(cookies, @uri) == :expired}
        header['Cookie'] = cookies[0..-3]                                 
      end
      if @refforge
        ref = @uri.root ? uri : (@webproxy ? @http.host : @root)+uri
        header['Referer'] = ref.match(/(.+)[^\/]*$/)[1]           
      end
      header['User-Agent'] = @ua == :rand ? UAS.rand : @ua if @ua
      header
    end
      
    def ProcCookies(res)
      ck = []
      case res
        when String
          res.split(/\r?\n/).each {|h|
            hs = h/': '
            ck << hs[1] if hs[0] and hs[0].downcase! == 'set-cookie'
          }
        when Curl::Response
          ck = res['cookies']
      end
      return if !ck.b
      ck.each {|c| Cookie(c, self)}
  #    StoreCookies if @cookieStore
    end

    def cp_on() @cookieProc = true end
    def cp_off() @cookieProc = false end
    
    def main_cks() @cookies[@uri.host] ||= {} end
    def main_cks=(cks)
      @cookies[@uri.host] = @webproxy ? 
        @webproxy.ck_encode(@root, cks) : 
        cks.map2 {|k, v| Cookie(k, v)}   
    end
    
    def retry?(err)
      # exc = ['0chan.ru', '2-ch.ru', 'www.nomer.org', 'nomer.org'].select_in('http://www.nomer.org') = ['www.nomer.org', 'nomer.org']
      exc = (@@retry.keys + @retry.keys).select_in @root
      return false if !exc.b
      # ['www.nomer.org', 'nomer.org'].every {|www| 'TimeoutError'.in({'nomer.org' => 'TimeoutError'}[www])} ?
      exc.no? {|e| err[0].self_name.in((@@retry[e] || []) + @retry[e])}
    end
    
    def loaded?
      $Carier.reqs.include? @http
    end
    
    def load!
      unless $Carier.add @http
        $Carier.remove @http
        $Carier.add @http
      end
    rescue RuntimeError => e
      e.message << ". Failed to load allready loaded? easy handler: Bad file descriptor" unless Curl::Err::CurlError === e
      raise e
    end
    
    def load(path=@path, headers={}, not_redir=1, relvl=10, &callback)
      @http.path = path = fix(path)
      @http.headers = mkHeader(path).merge!(headers)
      @http.timeout = @timeout

      @http.on_complete {|c|
        @error = nil
        @outdated = true
        ProcCookies c.res if @cookieProc
        # We cannot just cancel on_complete in on_redirect block
        # because loadGet will immediately reset on_complete back
        if c.res.code.in(300..399) and !not_redir.b and (relvl -= 1) > -1 and loc = c.res.hash.location
          loadGet(loc, headers: headers, relvl: relvl, redir: true, &callback)
        elsif block_given?
          yield c
        end
      }
      @http.on_failure {|c, e|
        @http.on_complete &Proc::NULL
        @outdated = true
        @error = e
        if retry? e
          L.debug "#{e[0]} -> reloading scout"
          #load uri, headers, not_redir, relvl, &callback
          load! # all params including post_body are still set
        else
          L.debug "#{e[0]} -> not reloading scout"
          raise *e if @raise_err
        end
      } if !@http.on_failure
      
      load!
    end

    def loadPost(*argv, &callback)
      hash, multipart, uri, opts = argv.get_opts [@body, false, @path], 
                                           :headers => {}, :redir => false, :relvl => 2
      mkBody hash, multipart.b
      @last_method	= :post
      if block_given?
        @post_proc	= callback
      else#if @http.callback != @post_proc
        callback = @post_proc 
      end
      load(uri, opts[:headers], !opts[:redir], opts[:relvl], &callback)
    end
    
    def loadGet(*argv, &callback)
      uri, opts = argv.get_opts [@path], 
                     :headers => {}, :redir => false, :relvl => 2
      @http.get	    = true
      @last_method	= :get
      if block_given?
        @get_proc	  = callback
      else#if @http.callback != @get_proc
        callback = @get_proc 
      end
      load(uri, opts[:headers], !opts[:redir], opts[:relvl], &callback)
    end
    
    def loadHead(*argv, &callback)
      uri, emulate, headers = argv.get_opts [@path, :if_retry]
      @http.head	  = true if emulate != :always
      @last_method	= :head
      if block_given?
        @head_proc	= callback
      else#if @http.callback != @head_proc
        callback = @head_proc 
      end
      emu = lambda {
        @headers = ''
        @http.on_header {|h|
          @headers << h
          h == "\r\n" ? 0 : h.size
        }
        @http.get	    = true
        load(uri, headers) {|c| c.on_header; callback[c]}
      }
      if emulate != :always
        load(uri, headers) {|c|
          if !@error and c.res.code != 200 and emulate == :if_retry
            emu.call
          else
            callback[c]
          end
        } 
      else emu.call
      end
    end
    
  end
  
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
        raise "Curl must run in order to use ScoutSquad#rand" if !Curl.status
        #Curl.wait
        loop {sleep 1; break if $Carier.reqs.size < size}
        self.rand 
      end 
    end
      
    def next
      raise PickError if !b
      if scout = find {|_|!_.loaded?}; scout
      else # Curl should run here, otherwise `next'/`rand'-recursion will cause stack overflow
        raise "Curl must run in order to use ScoutSquad#next" if !Curl.status
        #Curl.wait
        loop {sleep 1; break if $Carier.reqs.size < size}
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
  
  ### Global scope shortcut methods ###
  
module RMTools

  def Get(uri, opts={})
    raise ArgumentError, "Local uri passed to Get function" if uri[0,1] == '/'
    $log.debug "Protocol-less uri passed to Get function" if !uri[/^\w+:\/\//]
    headers	  = opts[:headers]	  || opts[:h]	  || {}
    proxy	      = opts[:proxy]	    || opts[:pr]	|| $CurlGetProxy
    ret_body	= opts.fetch(:ret_body, opts.fetch(:b, 1)).b
    wait	      = opts.fetch(:wait, opts.fetch(:w, !block_given?)).b
    s	        = HTTPAccessKit::Scout(uri, proxy, opts)
    buf	    = ret_body ? '' : s.http.res
    s.raise_err	    ||= opts[:e]
    s.http.timeout ||= opts[:t]
    s.loadGet(headers) {|c|
      if ret_body
        buf << c.body_str
      else
        buf.load_from c.res
      end
      yield buf if block_given?
    }
    if wait
      ($CarierThread and $CarierThread.status) ? Curl.wait : $Carier.perform
    end
    buf
  end
  module_function :Get
  
end
  
module Enumerable
  
  def GetAll(on_count=nil, default_domain=nil, &callback)
    if on_count
      len = size
      counter = 0
      send(resto(:each_value) ? :each_value : :each) {|uri|
        uri = File.join(default_domain, uri) if default_domain and (uri[0,1] == '/' or !uri[/^https?:/])
        Get(uri) {|buf|
          callback.arity > 1 ?
            callback.call(buf, counter) :
            callback.call(buf)
          if (counter += 1) == len
            on_count.arity > 0	?
              on_count.call(buf)	:
              on_count.call
          end
        }
      }
    else send(resto(:each_value) ? :each_value : :each) {|uri|
          Get(uri, &callback)          }
    end
  end

end