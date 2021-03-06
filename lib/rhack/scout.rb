# encoding: utf-8
module RHACK

  class Scout
    __init__
    attr_accessor	:timeout, :raise_err, :retry
    attr_accessor	:path, :root, :sld, :proxy
    attr_reader	    :uri
    attr_reader	    :webproxy, :last_method, :proxystr, :headers, :body, :http, :error
    attr_reader	    :cookies, :ua, :refforge, :cookies_enabled
    
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
      @cookies_enabled	= opts[:cp] || opts[:ck]
      @raise_err   	= opts[:raise] # no way to use @raise id, it makes any 'raise' call here fail
      @engine     	= opts[:engine]
      @timeout    	= opts[:timeout] || @@timeout || 60
      @post_proc	= @get_proc = @head_proc = @put_proc = @delete_proc = Proc::NULL
      update uri
      
      @retry = opts[:retry] || {}
      @retry = {@uri.host => @retry} if @retry.is Array
    end
    
    def setup_curl
      if loaded?
        Curl.carier.remove @http
      end
      @http = Curl::Easy(@webproxy ? @proxy : @root)
      @http.base = self       
      @http.cacert = @@cacert
    end
    
    def update(uri)
      if !uri[/^\w+:\/\//]
        uri = '/' + uri if uri[0,1] != '/'
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
        setup_curl
      end
      if @proxy
        @http.proxy_url = @proxy*':' if !@webproxy
        @proxystr = @webproxy ? @proxy[0] : @http.proxy_url
      else @proxystr = 'localhost' 
      end
      if @cookies_enabled.is Hash
        self.main_cks = @cookies_enabled
        @cookies_enabled = true    
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
    
    def res
      @http.res
    end
    
    def req 
      res.req
    end
    
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

    def mkBody(params, multipart=false)
      if multipart
        @http.multipart_post_body = @body = params.map {|k, v|
          v = v.call if v.is Proc
          if v[%r(^file://(.+))] or v.is Hash
            path = $1 || v[:path]
            name = v.is(Hash) && v[:name] ||
              File.basename(path)
            content_type = v.is(Hash) && v[:content_type].to_s ||
              (MIME::Types.of(path)[0] || {}).content_type ||
              "application/octet-stream"
            Curl::PostField.file(k, type, name, read(path))
          else
            Curl::PostField.content(k.to_s, v.to_s)
          end
        }
      else
        @http.post_body = case params
        when IO
          @body = params.read
          params.close
          @body
        when String
          @body = if params[%r(^file://(.+))]
            read $1
          else
            params
          end
        else
          @body = params.urlencode
        end
      end
    end
    
    def mkHeader(uri)
      header = DefaultHeader.dup
      if @cookies_enabled
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
      
    def process_cookies(res)
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
      return if ck.blank?
      ck.each {|c| Cookie(c, self)}
    end

    def cp_on() @cookies_enabled = true end
    def cp_off() @cookies_enabled = false end
    
    def main_cks() @cookies[@uri.host] ||= {} end
    def main_cks=(cks)
      @cookies[@uri.host] = @webproxy ? 
        @webproxy.ck_encode(@root, cks) : 
        cks.map2 {|k, v| Cookie(k, v)}   
    end
    
    def retry?(curl_err)
      # sites = ['0chan.ru', '2-ch.ru', 'www.nomer.org', 'nomer.org'].select_in('http://www.nomer.org') = ['www.nomer.org', 'nomer.org']
      sites = (@@retry.keys + @retry.keys).select_in @root
      return false if sites.empty?
      errname = curl_err.self_name
      # retry = ['www.nomer.org', 'nomer.org'].any? {|www| {'nomer.org' => ['TimeoutError']}[www].include? 'TimeoutError'}
      sites.any? {|site|
        (@@retry[site] || []).include? errname or 
        (@retry[site] || []).include? errname
      }
    end
    
    def retry!(path=@__path, headers=@__headers, not_redir=@__not_redir, relvl=@__relvl, callback=@__callback)
      # all external params including post_body are still set
      setup_curl # @http reload here
      # and now we can set @http.on_complete back again
      load(path, headers, not_redir, relvl, &callback)
    end
    
    def loaded?
      Curl.carier.reqs.include? @http
    end
    
    # Scout must not be reused until not only response will have come,
    # but callback will have been processed, too.
    # Otherwise, #retry! may not work as expected:
    # if a scout gets callback as a block argument, then it may re-run not original callback,
    # but it's copy with another scope.
    def available?
      !loaded? and !@busy
    end
    
    # - if curl should retry request based on Curl::Err class only
    #   => false
    def process_failure(curl_err, message, &callback)
      @error = curl_err.new message
      #@error = [curl_err, message] # old
      @http.outdate!
      # we must clean @http.on_complete, otherwise
      # it would run right after this function and with broken data
      @http.on_complete &Proc::NULL
      if retry? curl_err
        L.debug "#{curl_err} -> reloading scout"
        retry!
      else
        L.debug "#{curl_err} -> not reloading scout"
        begin
          raise @error if @raise_err
          #raise *@error if @raise_err # old
          yield if block_given?
        ensure
          # Now, we assume that data of this @http have been copied or will not be used anymore,
          # thus the scout can be reused.
          @busy = false
        end
      end
    end
    
    def load!
      unless Curl.carier.add @http
        L.warn "#{self}##{object_id}: Failed to add Curl::Easy##{@http.object_id} to Curl::Multi##{Curl.carier.object_id}. Trying to remove it and re-add."
        Curl.carier.remove @http
        Curl.сarier.add @http
      end
    rescue RuntimeError => e
      e.message << ". Failed to load allready loaded? easy handler: Bad file descriptor" unless Curl::Err::CurlError === e
      L.warn "#{self}##{object_id}: #{e.inspect}: #{e.message}"
      if loaded?
        Curl.carier.remove @http
      end
      sleep 1
      load!
    end
    
    def load(path=@path, headers={}, not_redir=1, relvl=10, &callback)
      @busy = true
      # cache preprocessed data for one time so we can do #retry
      @__path = path
      @__headers = headers
      @__not_redir = not_redir
      @__relvl = relvl
      @__callback = callback
      
      @http.path = path = fix(path)
      @http.headers = mkHeader(path).merge!(headers)
      @http.timeout = @timeout

      @http.on_complete {|curl| # = @http
        # @http has already been removed when a request had complete,
        # but this callback may occure wherever in a serial queue of curl callbacks.
        @error = nil
        # While not outdated, Curl::Response here may contain pointers on freed
        # memory, thus throwing exception on #to_s and #inspect
        @http.outdate!
        res = @http.res
        process_cookies res if @cookies_enabled
        # We cannot just cancel on_complete in on_redirect block,
        # because loadGet should (and will) immediately reset on_complete back.
        if res.code.in(300..399) and not_redir.blank? and (relvl -= 1) > -1 and loc = res.hash.location
          loadGet(loc, headers: headers, relvl: relvl, redir: true, &callback)
        else
          begin
            yield @http if block_given?
          ensure
            # Now, we assume that data of this @http have been copied or will not be used anymore,
            # thus the scout can be reused.
            @busy = false
            @http.on_failure &Proc::NULL
          end
        end
      }
      # Curl::Err::* (TCP/IP level) exception callback.
      # May be set out there.
      @http.on_failure {|curl, error|
        process_failure(*error)
      } unless @http.on_failure
      
      load!
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

    def loadDelete(*argv, &callback)
      uri, opts = argv.get_opts [@path], 
                     :headers => {}, :redir => false, :relvl => 2
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
      @http.delete = false
      unless hash.is Hash # not parameterized
        opts[:headers] = opts[:headers].reverse_merge 'Content-Type' => 'application/octet-stream'
      end
      mkBody hash, multipart.present?
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
      @http.delete = false
      @http.put_data = @body = body_or_file
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