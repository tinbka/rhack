# encoding: utf-8
module RHACK

    # Frame( ScoutSquad( Curl::Multi <- Scout( Curl API ), Scout, ... ) ) => 
    # Curl -> Johnson::Runtime -> XML::Document => Page( XML::Document ), Page, ... 
  
  class ZippingError < ArgumentError 
    def initialize debug, str="invalid use of :zip option, url and body must be an arrays with the same size\n               url: %s(%s), body: %s(%s)"
      super str%debug end
  end
    
  class TargetError < ArgumentError
    def initialize msg="only static frame can use local paths"
      super end
  end
    
  class ConfigError < ArgumentError
    def initialize msg
      super end
  end

  class Frame
    __init__
    attr_reader :loc, :static, :ss, :opts, :use_cache, :write_to
    alias options opts
    @@cache = {}
    
    def initialize *args
      #args << 10 unless args[-1].is Fixnum
      #args.insert -2, {} unless args[-2].is Hash
      #opts = args[-2]
      #if scouts = (opts[:scouts] || opts[:threads])
      #  args[-1] = scouts
      #end
      opts = args.find_by_class(Hash) || {}
      scouts_count = opts[:scouts] || opts[:threads] || 10
      @opts = {:eval => Johnson::Enabled, :redir => true, :cp => true, :result => Page}.merge!(opts)
      if args[0].is String
        url = args[0].dup
        'http://' >> url if url !~ /^\w+:\/\//
        update_loc url
      else
        @loc = {}
        @static = false
      end
      @ss  = ScoutSquad @loc.href, @opts, scouts_count
    end
    
    def update_loc url
      @loc = url.parse :uri
      # be careful, if you set :static => false, frame will be unable to use "path" url
      @static = @opts.fetch(:static, @loc)
    end
    
    def retarget to, forced=nil
      to = 'http://' + to if to !~ /^\w+:/
      @ss.update to, forced
      update_loc to
    end
    alias target= retarget
    
    def anchor
      retarget @loc.href
    end
    
    def next() @ss.next end
    def rand() @ss.rand end
    def each(&block) @ss.each &block end
    def [](i) @ss[i] end
    
    def copy_cookies! i=0
      @ss.each {|s| s.cookies.replace @ss[i].cookies}
    end
    
    def use_cache! opts={}
      if opts == false
        @use_cache = false
      else
        @@cache = opts[:pages].kinda(Hash) ? opts[:pages] : opts[:pages].map_hash {|p| [p.href, p]} if opts[:pages]
        #@write_to = opts[:write_to] if :write_to.in opts
        @use_cache = true
      end
    end
    
    def drop_cache! use=nil
      @@cache.clear
      GC.start
      @use_cache = use if use.in [true, false]      
    end
    
    def inspect
      sssize = @ss.size
      "<#Frame @ #{@ss.untargeted ? 'no target' : @loc.root}: #{sssize} #{sssize == 1 ? 'scout' : 'scouts'}#{', static'+(' => '+@static.protocol if @static.is(Hash)) if @static}, cookies #{@ss[0].cookieProc ? 'on' : 'off'}>"
    end
    
    # All opts going in one hash.
    # Opts for Frame:
    #   :wait, :proc_result, :save_result, :zip, :thread_safe, :result, :stream, :raw, :xhr, :content_type
    # Opts passed to Page:
    #   :xml, :html, :json, :hash, :eval, :load_scripts
    # Opts for Scout:
    #   :headers, :redir, :relvl
    # TODO: describe options
    def exec *args, &callback
      many, order, orders, with_opts = interpret_request *args
      L.log({:many => many, :order => order, :orders => orders, :with_opts => with_opts})
      
      if !Johnson::Enabled and with_opts[:eval]
        L < "failed to use option :eval because Johnson is disabled"
        with_opts.delete :eval
      end
      # JS Runtime is not thread-safe and must be created in curl thread
      # if we aren't said explicitly about the opposite
      Johnson::Runtime.set_browser_for_curl with_opts
      
      if many then	exec_many orders, with_opts, &callback
      else 	          exec_one order, with_opts, &callback    end
    end
    alias :get :exec
    alias :run :get
    
    def interpret_request(*args)
      body, mp, url, opts = args.dup.get_opts [nil, false, nil], @opts
      L.log [body, mp, url, opts]
      zip = opts.delete :zip
      verb = opts.delete :verb
      put = verb == :put
      post = put || verb == :post
      many = order = orders = false
      
      if put
        # If request is PUT then first argument is always body
        if mp.is String
          # and second is URL if specified
          url = mp.dup
        else
          url = nil
        end
      else
        # Default options set is for POST
        if mp.is String or mp.kinda Array and !(url.is String or url.kinda Array)
        # if second arg is String then it's URL
          url, mp, post = mp.dup, false, true
        # L.debug "URL #{url.inspect} has been passed as second argument instead of third"
        # But if we have only one argument actually passed 
        # except for options hash then believe it's GET
        elsif body.is String or body.kinda [String] # mp is boolean
          if post
            url = url.dup if url
          else
            L.debug "first parameter (#{body.inspect}) was implicitly taken as url#{' '+body.class if body.kinda Array}, but last paramter is of type #{url.class}, too" if url
            url = body.dup
          end
        elsif !body
          url = nil
        else
          url = url.dup if url
          mp, post = !!mp, true
        end
      end
      
      if post
        validate_zip url, body if zip
        if zip or url.kinda Array or body.kinda Array
          many    = true
          unless put or body.kinda [Hash]
            raise TypeError, "body of POST request must be a hash array, params was
       (#{args.inspect[1..-2]})"
          end
     
          if zip or url.kinda Array
            validate_some url
            orders = zip ? body.zip(url) : url.xprod(body, :inverse)
          else
            url = validate url
            orders = body.xprod url
          end
          if put
            orders.each {|o| o.unshift :loadPut}
          else
            orders.each {|o| o.unshift :loadPost and o.insert 2, mp}
          end
        else
          if put
            unless body.is String
              raise TypeError, "body of PUT request must be a string, params was
         (#{args.inspect[1..-2]})"
            end
          else
            unless body.is Hash or body.is String
              raise TypeError, "body of POST request must be a hash or a string params was
         (#{args.inspect[1..-2]})"
            end
          end
     
          url = validate url
          order = put ? [:loadPut, body, url] : [:loadPost, body, mp, url]
        end
      else
        del = verb == :delete
        if url.kinda Array
          many  = true
          validate_some url
          orders = [del ? :loadDelete : :loadGet].xprod url
        else
          url = validate url
          order = [del ? :loadDelete : :loadGet, url]
        end
      end
      if !order.b and !orders.b
        raise ArgumentError, "failed to run blank request#{'s' if many}, params was
     (#{args.inspect[1..-2]})"
      end
   
      opts[:wait] = opts[:sync] if :sync.in opts
      opts[:wait] = true if !:wait.in(opts) and 
                    :proc_result.in(opts) ? !opts[:proc_result] : opts[:save_result]
                    
      opts[:eval] = false if opts[:json] or opts[:hash] or opts[:raw]
      opts[:load_scripts] = self if opts[:load_scripts]
      opts[:stream] = true if opts[:raw]
      
      (opts[:headers] ||= {})['X-Requested-With'] = 'XMLHttpRequest' if opts[:xhr]
      if opts[:content_type]
        if opts[:content_type].is Symbol
          if mime_type = MIME::Types.of(opts[:content_type])[0]
            (opts[:headers] ||= {})['Content-Type'] = mime_type.content_type
          else
            raise ArgumentError, "failed to detect Mime::Type by extension: #{opts[:content_type]}
        (#{args.inspect[1..-2]})"
          end
        else
          (opts[:headers] ||= {})['Content-Type'] = opts[:content_type]
        end
      end
      
      [many, order, orders, opts]
    end
    
  private
    def validate_zip(url, body)
      if !(url.kinda Array and body.kinda Array)
        raise ZippingError, [url.class, nil, body.class, nil]
      elsif url.size != body.size
        raise ZippingError, [url.class, url.size, body.class, body.size]
      end
    end
    
    # :static option now can accept hash with :procotol key, in that case Frame can be relocated to the same domain on another protocol and default protocol would be the value of @static.protocol
    # if @static option has a :host value as well then it works just like a default route
    def validate(url)
      if url
        loc = url.parse:uri
        if loc.root and loc.root != @loc.root
          if @static
            if @static.is Hash
              if loc.host != @loc.host and !@static.host
                raise TargetError, "unable to get #{url} by a static frame [#{@static.protocol}://]#{@loc.host}, you should first update it with a new target"
              end
            else
              raise TargetError, "unable to get #{url} by a static frame #{@loc.root}, you should first update it with a new target"
            end
          end
          @loc.root, @loc.host, @loc.protocol = loc.root, loc.host, loc.protocol
          url
        elsif !loc.root
          if !@static
            raise TargetError, "undefined root for query #{url}, use :static option as Hash to set a default protocol and host, or as True to allow using previously used root"
          elsif @static.is Hash
            # targeting relatively to default values (from @static hash)
            @loc.protocol = @static.protocol
            @loc.host = @static.host if @static.host
            @loc.root = @loc.protocol+'://'+@loc.host
          end
          if !@loc.host
            raise TargetError, "undefined host for query #{url}, use :host parameter of :static option to set a default host"
          end
          File.join @loc.root, url
        else url
        end
      else
        raise TargetError if !@static
        @loc.href
      end
    end
    
    def validate_some(urls)
      urls.map! {|u| validate u}
    end
    
    # Feature of :proc_result in that, if you running synchronously,
    # result of #run will be, for conviniency, `page.res` instead of `page`
    #
    # If you only need to transfer &block through a stack of frame callbacks
    # just add &block to the needed #run call
    #
    # If you want a method to be processable as in async-mode with &block passed
    # as in sync-mode with no &block passed
    # pass :save_result => !block to the topmost #run call
    def run_callbacks!(page, opts, &callback)
      # if no callback must have run then page.res is equal to the page
      # so we can get the page as result of a sync as well as an async request
      page.res = page
      if callback
        yres = callback.call page
        # if we don't want callback to affect page.res 
        # then we should not set :save_result
        if yres != :skip
          if opts[:proc_result].is Proc
            # yres is intermediate result that we should proc
            page.res = opts[:proc_result].call yres
          elsif opts[:save_result] or :proc_result.in opts
            # yres is total result that we should save
            page.res = yres
          end
          # in both cases page.res is set to total result
          # so we can return result from any depth as @res attribute of what we have on top
        end
      end
    end
    
    # TODO: found why/how IO on callbacks breaks +curl.res.body+ content and how to fix or how to avoid it
    def exec_one(order, opts, &callback)
      if @use_cache and order[0] == :loadGet and page = @@cache[order[1]]
        run_callbacks! page, opts, &callback
        res = opts[:wait] && (opts[:save_result] or :proc_result.in opts) ? page.res : page
        return res
      end
      # must result in Page (default) or it's subclass
      page = opts[:result].new
      # if no spare scouts can be found, squad simply waits for first callbacks to complete
      s = @ss.next
      s.http.on_failure {|curl, error|
        if s.process_failure(*error)
          # curl itself has decided not to retry a request
          if opts[:raw]
            page.res = s.error
          elsif page.process(curl, opts)
            run_callbacks! page, opts, &callback
            # nothing to do here if process returns nil or false
          end
        end
      }
      s.send(*(order << opts)) {|curl|
      #   there is a problem with storing html on disk
        if order[0] == :loadGet and @write_to
      #     sometimes  (about 2% for 100-threads-dling) when this string is calling
      #     no matter what +curl.res.body+ has contained here
          RMTools.rw @write_to+'/'+order[-2].sub(/^[a-z]+:\/\//, ''), curl.res.body.xml_to_utf
        end
        if opts[:raw]
          page.res = block_given? ? yield(curl) : curl.body_str
      #   here +curl.res.body+ becomes empty
      #   curl.res.body.+xml_to_utf+ -- maybe this is problem?
        elsif page.process(curl, opts)
          @@cache[page.href] = page if order[0] == :loadGet and @use_cache
          run_callbacks! page, opts, &callback
          # nothing to do here if process returns nil or false
        end
      }
      # > Carier.requests++
      unless opts[:wait] and opts[:thread_safe] or opts[:exec] == false
        Curl.execute :unless_already
      end
      if opts[:wait]
        opts[:thread_safe] ? Curl.carier.perform : Curl.wait
        (opts[:save_result] or :proc_result.in opts) ? page.res : page
      else page
      end
    end
    
    def exec_many(orders, with_opts, &callback)
      w = with_opts.delete :wait
      iterator = with_opts[:stream] ? :each : :map
      if with_opts[:ranges]
        if orders.size != with_opts[:ranges].size
          raise ZippingError, [orders.size, with_opts[:ranges].size], "orders quantity (%s) is not equal ranges quantity (%s)" 
        end
        pages = orders.zip(with_opts[:ranges]).send(iterator) {|order, range| 
          (with_opts[:headers] ||= {}).Range = "bytes=#{range.begin}-#{range.end}"
          exec_one order, with_opts.merge(:exec => false), &callback
        }
      else
        # если ss.next будет не хватать скаутов, то он сам запустит курл
        # правда, это с :thread_safe никак не вяжется
        pages = orders.send(iterator) {|order| exec_one order, with_opts, &callback }
      end
      unless w and with_opts[:thread_safe] or opts[:exec] == false
        Curl.execute :unless_already
      end
      with_opts[:thread_safe] ? Curl.carier.perform : Curl.wait if w
      with_opts[:stream] || pages
    end
    
  end
  
end