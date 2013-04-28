# encoding: utf-8
module RHACK

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
      @timeout    	= opts[:timeout] || @@timeout || 60
      @post_proc	= @get_proc = @head_proc = @put_proc = @delete_proc = Proc::NULL
      update uri
      @retry = opts[:retry] || {}
      @retry = {@uri.host => @retry} if @retry.is Array
      
      @http.cacert = @@cacert
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
        @http.multipart_post_body = @body = params.map {|k, v|
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
        @http.post_body = @body = params.urlencode
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
      header['User-Agent'] = @ua == :rand ? RHACK.useragents.rand : @ua if @ua
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
      Curl.carier.reqs.include? @http
    end
    
    def load!
      unless Curl.carier.add @http
        Curl.carier.remove @http
        Curl.сarier.add @http
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
        if e[0] == Curl::Err::CurlOK
          @error = e
          # TODO: где-то в сорцах on_failure вызывается по коду 0, видимо из-за стороннего условия, а не должен
          L.log << "Got Curl::Err::CurlOK, response was: #{c.res}"
        else
          @http.on_complete &Proc::NULL
          @outdated = true
          if retry? e
            L.debug "#{e[0]} -> reloading scout"
            #load uri, headers, not_redir, relvl, &callback
            load! # all params including post_body are still set
          else
            L.debug "#{e[0]} -> not reloading scout"
            raise *e if @raise_err
          end
        end
      } if !@http.on_failure
      
      load!
    end
    
    def loadGet(*argv, &callback)
      uri, opts = argv.get_opts [@path], 
                     :headers => {}, :redir => false, :relvl => 2
      # curl_easy_setopt here internally replaces current method by GET
      @http.get	    = true
      @last_method	= :get
      if block_given?
        @get_proc	  = callback
      else#if @http.callback != @get_proc
        callback = @get_proc 
      end
      load(uri, opts[:headers], !opts[:redir], opts[:relvl], &callback)
    end

    def loadDelete(*argv, &callback)
      uri, opts = argv.get_opts [@path], 
                     :headers => {}, :redir => false, :relvl => 2
      # curl_easy_setopt here internally replaces current method by DELETE
      @http.delete = true
      @last_method	= :delete
      if block_given?
        @delete_proc	= callback
      else#if @http.callback != @post_proc
        callback = @delete_proc 
      end
      load(uri, opts[:headers], !opts[:redir], opts[:relvl], &callback)
    end

    def loadPost(*argv, &callback)
      hash, multipart, uri, opts = argv.get_opts [@body, @http.multipart_form_post?, @path], :headers => {}, :redir => false, :relvl => 2
      # curl_easy_setopt here internally replaces current method by POST
      mkBody hash, multipart.b
      @last_method	= :post
      if block_given?
        @post_proc	= callback
      else#if @http.callback != @post_proc
        callback = @post_proc 
      end
      load(uri, opts[:headers], !opts[:redir], opts[:relvl], &callback)
    end

    def loadPut(*argv, &callback)
      body_or_file, uri, opts = argv.get_opts [@body, @path], 
                             :headers => {}, :redir => false, :relvl => 2
      # curl_easy_setopt here internally replaces current method by PUT
      @http.put_data = @body = body
      @last_method	= :put
      if block_given?
        @put_proc	= callback
      else#if @http.callback != @post_proc
        callback = @put_proc 
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
  
end