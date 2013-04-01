# encoding: utf-8
module HTTPAccessKit

    # Frame( ScoutSquad( Curl::Multi <- Scout( Curl API ), Scout, ... ) ) => 
    # Curl -> Johnson::Runtime -> XML::Document => Page( XML::Document ), Page, ... 
  
  class ZippingError < ArgumentError 
    def initialize debug, str="invalid use of :zip option, uri and body must be an arrays with the same size\n               uri: %s(%s), body: %s(%s)"
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
    @@cache = {}
    
    def initialize *args
      args << 10 unless args[-1].is Fixnum
      args.insert -2, {} unless args[-2].is Hash
      @opts = {:eval => Johnson::Enabled, :redir => true, :cp => true, :result => Page}.merge!(args[-2].kinda(Hash) ? args[-2] : {})
      args[-2] = @opts
      if args[0].is String
        uri = args[0]
        'http://' >> uri if uri !~ /^\w+:\/\//
        @loc = uri.parse:uri
        # be careful, if you set :static => false, frame will be unable to use implicit url
        @static = @opts.fetch(:static, true)
      else
        @loc = {}
        @static = false
      end
      @ss  = ScoutSquad *args
      Curl.run :unless_allready
    end
    
    def retarget to, forced=nil
      to = 'http://' + to if to !~ /^\w+:/
      @ss.update to, forced
      @loc = to.parse:uri
    end
    alias :target= :retarget
    
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
      "<#Frame @ #{@ss.untargeted ? 'no target' : @loc.root}: #{'scout'.x @ss.size}#{', static'+(' => '+@static.protocol if @static.is(Hash)) if @static}, cookies #{@ss[0].cookieProc ? 'on' : 'off'}>"
    end
    
    # opts are :eval, :json, :hash, :wait, :proc_result, :save_result, :load_scripts, 
    # :zip, :thread_safe, :result, :stream, :raw, :xhr + any opts for Scouts in one hash
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
      body, mp, uri, opts = args.dup.get_opts [nil, false, nil], @opts
      L.log [body, mp, uri, opts]
      zip = opts.delete :zip
      many = order = orders = post = false
      # Default options set is for POST
      if mp.is String or mp.kinda Array and !(uri.is String or uri.kinda Array)
      # if second arg is String, then that's uri
        uri, mp, post = mp.dup, false, true
      #  L.debug "uri #{uri.inspect} has been passed as second argument instead of third"
      # But if we have only one argument actually passed 
      # except for options hash, then believe it's GET
      elsif body.is String or body.kinda [String]
        L.debug "first parameter (#{body.inspect}) was implicitly taken as uri#{' '+body.class if body.kinda Array}, but last paramter is of type #{uri.class}, too" if uri
        uri = body.dup
      elsif !body then uri = nil
      else
        uri = uri.dup if uri
        mp, post = !!mp, true
      end
      if post
        unless body.is Hash or body.kinda [Hash]
          raise TypeError, "body of post request must be a hash or hash array, params was
     (#{args.inspect[1..-2]})"
        end
        validate_zip uri, body if zip
        if zip or uri.kinda Array or body.kinda Array
          many    = true
          if zip or uri.kinda Array
            validate_some uri
            orders = zip ? body.zip(uri) : uri.xprod(body, :inverse)
          else
            uri = validate uri
            orders = body.xprod uri
          end
          orders.each {|o| o.unshift :loadPost and o.insert 2, mp}
        else
          uri = validate uri
          order = [:loadPost, body, mp, uri]
        end
      else
        if uri.kinda Array
          many  = true
          validate_some uri
          orders = [:loadGet].xprod uri
        else
          uri = validate uri
          order = [:loadGet, uri]
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
      [many, order, orders, opts]
    end
    
    def get_cached(*links)
      res = []
      expire = links[-1] == :expire ? links.pop : false
      links.parses(:uri).each_with_index {|uri, i|
        next if uri.path[/ads|count|stats/]
        file = Cache.load uri, !expire
        if file
          if expire
            @ss.next.loadGet(uri.href, :headers=>{'If-Modified-Since'=>file.date}) {|c|
              if c.res.code == 200
                res << [i, (data = c.res.body)]
                Cache.save uri, data, false
              else
                res << [i, file.is(String) ? file : read(file.path)]
              end
            }
          else
            res << [i, file.is(String) ? file : read(file.path)]
          end
        else
          @ss.next.loadGet(uri.href) {|c|
            if c.res.code == 200
              res << [i, (data = c.res.body)]
              Cache.save uri, data, !expire
            end
          }
        end
      }
      Curl.wait
      links.size == 1 ? res[0][1] : res.sort!.lasts
    end
    
    def get_distr(uri, psize, threads, start=0, print_progress=$verbose)
      raise ConfigError, "Insufficient Scouts in the Frame for distributed downloading" if @ss.size < 2
      @print_progress, code, stop_download, @ss_reserve = print_progress, nil, false, []
      (s = @ss.next).http.on_header {|h|
        next h.size unless h[/Content-Length: (\d+)|HTTP\/1\.[01] (\d+)[^\r]+|^\s*$/]
        if code = $2
          if code != '200'
            L << "#$& getting #{uri}; interrupting request."
            s.http.on_header() # set default process
            next 0
          end
          next h.size
        end
        
        s.http.on_header() # set default process
        if !$1 # конец хедера, content-length отсутствует
          L << "No Content-Length header; trying to load a whole #{uri} at once!"
          s.loadGet {|c| yield c.res.body.size, 0, c.res.body}
          next 0
        end
        
        len = $1.to_i - start
        psize = configure_psize(len, psize, threads)
        parts = (len/psize.to_f).ceil
        setup_speedometer(uri, parts, len)
        yield len, psize, :careful_dl if len > (@opts[:careful_dl] || 10.mb)
        
        @ss_reserve = @ss[threads+1..-1]
        @ss = @ss[0..threads]
        (0...parts).each {|n|
          break if stop_download
          
          s = @ss.next
          run_speedometer(s, len, n)
          s.loadGet(uri, :headers => {
            'Range' => "bytes=#{start + n*psize}-#{start + (n+1)*psize - 1}"
          }) {|c|
            clear_speedometer(s)
            if c.res.code/10 == 20
              yield len, n*psize, c.res.body
            else
              L << "#{c.res} during get #{uri.inspect}; interrupting request."
              stop_download = true
            end
          }
        }
        0
      }
      s.raise_err = false
      s.loadGet validate uri
    ensure
      @ss.concat @ss_reserve || []
    end
    
    def dl(uri, df=File.basename(uri.parse(:uri).path), psize=:auto, opts={})
      dled = 0
      lock = ''
      callback = lambda {|len, pos, body|
        if body != :careful_dl
          begin
            write(df, body, pos)
          rescue => e
            binding.start_interaction
            raise
          end
          if (dled += body.size) == len
            File.delete lock if File.file? lock
            yield df if block_given?
          end
        else
          lock = lock_file df, len, pos # filename, filesize, partsize
        end
      }
      opts[:threads] ||= @ss.size-1
      get_distr(uri, psize, opts[:threads], opts[:start].to_i, &callback)
      Curl.wait unless block_given?
      df
    end
    
    def simple_dl(uri, df=File.basename(uri.parse(:uri).path), opts={})
      opts.reverse_merge! :psize => :auto, :threads => 1, :print_progress => $verbose
      L << opts
      
      @print_progress = opts[:print_progress]
      unless len = opts[:len] || (map = read_mapfile(df) and map.len)
        return @ss.next.loadHead(uri) {|c| $log << c
          if len = c.res['Content-Length']
            simple_dl(uri, df, opts.merge(:len => len.to_i))
          else L.warn "Can't get file size, so it has no sence to download this way. Or maybe it's just an error. Check ObjectSpace.find(#{c.res.object_id}) out."
          end
        }
      end
      
      psize, parts = check_mapfile(df, opts)
      return unless psize
      L << [psize, parts]
      setup_speedometer(uri, parts.size, len)
      
      obtained uri do |uri|
        if opts[:threads] == 1
          start = opts[:start].to_i || (parts[0] && parts[0].begin) || 0
          scout = opts[:scout] || @ss.next
          $log << [uri, scout]
          (loadget = lambda {|n|
            run_speedometer(scout, len, n)
            from = start + n*psize
            to = start + (n+1)*psize - 1
            scout.loadGet(uri, :headers => {'Range' => "bytes=#{from}-#{to}"}) {|c|
              begin
                $log << "writing #{df} from #{from}: #{c.res.body.inspect}"
                write(df, c.res.body, from)
              rescue => e
                binding.start_interaction
                raise
              end
              if write_mapfile(df, from, to)
                clear_speedometer(scout)
                L.warn "file completely dl'ed, but (n+1)*psize <= len: (#{n}+1)*#{psize} <= #{len}" if (n+1)*psize <= len 
                yield df if block_given?
              elsif (n+1)*psize <= len 
                loadget[n+1] 
              end
            }
          })[0]
        else
          exec(uri, opts.merge(:raw => true, :ranges => parts)) {|c|
            L << c.res
            range = c.req.range
            begin
              write(df, c.res.body, range.begin)
            rescue => e
              binding.start_interaction
              raise
            end
            if write_mapfile(df, range.begin, range.end)
              @ss.each {|s| s.http.on_progress} if @print_progress
              yield df if block_given?
            end
          }
        end
      end
    end
    
    def check_mapfile(df, opts={})
      opts.reverse_merge! :psize => :auto, :threads => 1
      map = read_mapfile df
      if map
        L << map
        if map.rest.empty?
          puts "#{df} is loaded"
          $log << 'deleting mapfile'
          File.delete df+'.map'
          []
        else
          if opts[:len] and map.len != opts[:len]
            raise "Incorrect file size for #{df}"
          end
          psize = configure_psize *opts.values_at(:len, :psize, :threads)
          [psize, map.rest.div(psize)]
        end
      else
        write_mapfile df, opts[:len]
        psize = configure_psize *opts.values_at(:len, :psize, :threads)
        $log << (0...opts[:len]).div(psize)
        [psize, (0...opts[:len]).div(psize)]
      end
    end
      
    def read_mapfile(df)
      df += '.map'
      text = read df
      $log << "mapfile read: #{text}"
      if text.b
        text[/^(\d+)\0+(\d+)\0*\n/]
        map = {}
        $log << [$1,$2]
        if $1 and $1 == $2
          map.rest = []
        else
          map.len, *map.parts = text.chop/"\n"
          map.len = map.len.to_i
          map.parts.map! {|part| part /= '-'; part[0].to_i..part[1].to_i}
          $log << map.parts
          map.rest = (0...map.len) - XRange(*map.parts)
        end
        map
      end
    end
    
    def write_mapfile(df, *args)
      df += '.map'
      map = ''
      if args.size != 2
        len = args.shift
        map << len.to_s.ljust(22, "\0") << "\n" if File.file? df
      end
      if args.any?
        read(df)[/^(\d+)\0+(\d+)\0*\n/]
        $log << "mapfile read"
        $log << [$1,$2]
        dled = $2.to_i + args[1] - args[0] + 1
        return true if dled == $1.to_i
        map << "#{args[0]}..#{args[1]}\n"
        $log << 'writing mapfile'
        write(df, dled.to_s.ljust(11, "\0"), 11)
      end
      $log << [df, map]
      $log << 'writing mapfile'
      write df, map
      nil
    end
    
    def configure_psize(len, psize, threads)
      case psize
        when Numeric; psize.to_i
        when :auto; len > 100000 ? len/threads+1 : len
        when :mb; 1.mb
        else raise ArgumentError, "Incorrect value for part size #{psize}:#{psize.class}"
      end
    end
    
  private
    def validate_zip(uri, body)
      if !(uri.kinda Array and body.kinda Array)
        raise ZippingError, [uri.class, nil, body.class, nil]
      elsif uri.size != body.size
        raise ZippingError, [uri.class, uri.size, body.class, body.size]
      end
    end
    
    # :static option now can accept hash with :procotol key, in that case Frame can be relocated to the same domain on another protocol and default protocol would be the value of @static.protocol
    def validate(uri)
      if uri
        loc = uri.parse:uri
        if loc.root and loc.root != @loc.root
          if @static
            if @static.is Hash
              if loc.host != @loc.host
                raise TargetError, "unable to get #{uri} by static frame [#{@static.protocol}://]#{@loc.host}, you should first update it with new target"
              end
            else
              raise TargetError, "unable to get #{uri} by static frame #{@loc.root}, you should first update it with new target"
            end
          end
          @loc.root, @loc.host, @loc.protocol = loc.root, loc.host, loc.protocol
          uri
        elsif !loc.root
          raise TargetError if !@static
          if @static.is Hash
            @loc.protocol = @static.protocol
            @loc.root = @loc.protocol+'://'+@loc.host
          end
          File.join @loc.root, uri
        else uri
        end
      else
        raise TargetError if !@static
        @loc.href
      end
    end
    
    def validate_some(uris)
      uris.map! {|u| validate u}
    end
    
    def run_callbacks!(page, opts, &callback)
      if callback
        yres = callback.call page
        if opts[:save_result] or :proc_result.in opts
          page.res = yres
        end
        if opts[:proc_result].is Proc and yres != :skip
          opts[:proc_result].call yres
        end
      elsif opts[:save_result] or :proc_result.in opts
        page.res = yres
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
      s.send(*(order << opts)) {|curl|
      #   there is a problem with storing html on disk
        if order[0] == :loadGet and @write_to
      #     sometimes  (about 2% for 100-threads-dling) when this string is calling
      #     no matter what +curl.res.body+ has contained here
          RMTools.rw @write_to+'/'+order[-2].sub(/^[a-z]+:\/\//, ''), curl.res.body.xml_to_utf
        end
        if opts[:raw]
          yield curl
      #   here +curl.res.body+ become empty
        elsif page.process(curl, opts)
          @@cache[page.href] = page if order[0] == :loadGet and @use_cache
          run_callbacks! page, opts, &callback
        end
      }
      if opts[:wait]
        opts[:thread_safe] ? $Carier.perform : Curl.wait
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
          exec_one order, with_opts, &callback
        }
      else
        pages = orders.send(iterator) {|order| exec_one order, with_opts, &callback }
      end
      with_opts[:thread_safe] ? $Carier.perform : Curl.wait if w
      with_opts[:stream] || pages
    end
    
    
    def setup_speedometer(uri, parts, len)
      return  unless  @print_progress
      @progress = Array.new(parts, 0)
      @stop_print, @speed, @sum, *@speedometer = false, '', 0, Time.now, 0
      @str = "Downloading #{uri.gsub '%', '%%'} (#{len.bytes}) in %03s streams, %07s/s:"
      @bs = "\b\r"*(@newlines = (uri.unpack('U*').size+len.bytes.size+42)/(ENV['COLUMNS'] || 80).to_i)
      Thread.new {
        until @stop_print
          sleep 0.2
          now = Time.now
          if now > @speedometer[0] and @sum > @speedometer[1]
            @speed.replace(((@sum - @speedometer[1])/(now - @speedometer[0])).to_i.bytes)
            @speedometer.replace [now, @sum]
          end
        end
      }
    end
    
    def run_speedometer(scout, len, n)
      return  unless  @print_progress
      scout.http.on_progress {|dl_need, dl_now, *ul|
        if !@stop_print
          @progress[n] = dl_now
          percents = (@sum = @progress.sum)*100/len
          print @str%[@progress.select_b.size, @speed]+"\n%%[#{'@'*percents}#{' '*(100-percents)}]\r\b\r"+@bs
          if percents == 100
            puts "\v"*@newlines
            @stop_print = true
          end
        end
        true
      }
    end
    
    def clear_speedometer(scout)
      return  unless  @print_progress
      scout.http.on_progress
    end
    
  end
  
  def dl(uri, df=File.basename(uri.parse(:uri).path), threads=5, timeout=600, &block)
    Curl.run
    Frame({:timeout=>timeout}, threads).dl(uri, df, :auto, threads, &block)
  end
  module_function :dl
  
  

  class Page
    # for debug, just enable L#debug, don't write tons of chaotic log-lines 
    __init__
    # res here is result of page processing made in frame context
    attr_writer :title
    attr_reader :html, :loc, :hash, :doc, :js, :curl_res, :failed
    attr_accessor :res
    @@ignore = /google|_gat|tracker|adver/i
      
    def initialize(obj='', loc=Hash.new(''), js=$JSRuntime||Johnson::Runtime.new)
      loc = loc.parse:uri if !loc.is Hash
      @js = js
      if obj.is Curl::Easy or obj.kinda Scout
        c = obj.kinda(Scout) ? obj.http : obj
        @html = ''
        # just (c, loc) would pass to #process opts variable that returns '' on any key
        process(c, loc.b || {})
      else
        @html = obj
        @loc = loc
      end
    end
    
    def empty?
      !(@hash.nil? ? @html : @hash).b
    end
        
    def inspect
      if !@hash.nil?
        "<#FramePage (#{@hash ? @hash.inspect.size.bytes : 'failed to parse'}) #{@json ? 'json' : 'params hash'}>"
      else
        "<#FramePage #{@html.b ? "#{@failed ? @curl_res.header : '«'+title(false)+'»'} (#{@html.size.bytes}" : '(empty'})#{' js enabled' if @js and @doc and @hash.nil?}>"
      end
    end
    
    def html!(encoding='UTF-8')
      @html.force_encoding(encoding)
    end
    
    # We can then alternate #process in Page subclasses
    # Frame doesn't mind about value returned by #process
    def process(c, opts={})
      @loc = c.last_effective_url.parse:uri
      @curl_res = c.res
      L.debug "#{@loc.fullpath} -> #{@curl_res}"
      if @curl_res.code == 200
        body = @curl_res.body
        if opts[:json]
          @json = true
          @hash = begin; body.from_json
          rescue StandardError
            false 
          end
          if !@hash or @hash.is String
            L.debug "failed to get json from #{c.last_effective_url}, take a look at my @doc for info; my object_id is #{object_id}"
            @html = body; to_doc
            @hash = false
          end
          
        elsif opts[:hash]
          if body.inline
            @hash = body.to_params
          else
            @hash = false
            L.debug "failed to get params hash from #{c.last_effective_url}, take a look at my @doc for info; my object_id is #{object_id}"
            @html = body; to_doc
          end
          
        else
          @html = body.xml_to_utf
          to_doc
          if opts[:eval]
            load_scripts opts[:load_scripts]
            eval_js
          end
        end
      elsif !(opts[:json] or opts[:hash])
        @html = @curl_res.body
        @failed = @curl_res.code
      end
      self
    end
    
    def eval_js(frame=nil)
      eval_string "document.location = window.location = #{@loc.to_json};
      document.URL = document.baseURI = document.documentURI = location.href;
      document.domain = location.host;"
      find("script").each {|n|
        L.debug n.text.strip
        if text = n.text.strip.b
          js[:write_output] = ''
          eval_string text
          if res = js[:write_output].b then n.after res end
          n.remove!
        elsif frame and n.src
          eval_string frame.get_cached expand_link n.src
        end
      }
    end
    
    def eval_string(str)
      @js ||= Johnson::Runtime.new
      L.debug "#{@js} evaluating in #{Thread.current}\nmain: #{Thread.main}; carier: #{$CarierThread}"
      begin
        @js.evaluate(str)
      rescue Johnson::Error => e
        L.warn e.message
        L.debug {
          if m = e.message.match(/(\w+) is undefined|([\w.]+) is not a function/)
            L.clr.hl! str, /\b#{m[1] || m[2]}\b/
          end
          "\n\t#{str}"
        }
      end
    end
    
    def to_doc
      @doc = @html.to_doc :forceutf
    end
    
    def title(full=true)
      if @hash.nil? and !@failed and @html.b
        if full
          to_doc unless defined? @doc
          if @doc.title.b
            @title = @doc.title
          else
            @title = @loc.href
            @doc.at('head').prepend XML::Node('title', @title) if @doc.at('head')
            @title
          end
        else
          title true unless defined? @title
          if RUBY_VERSION < '1.9' and @title.cyr? and UTF2ANSI[@title].size > 40
            @short_title = ANSI2UTF[UTF2ANSI[@title][/.{1,30}\S*/][0..38]]+'…'
          elsif @title.size > 40
            @short_title = @title[/.{1,30}\S*/][0..38]+'…'
          else
            @short_title = @title
          end
        end
      else
        @loc.href
      end
    end
      
    def find(xp) (@doc || to_doc).find xp end
    
    def at(xp) (@doc || to_doc).at xp end
    
    def url() @loc.href end
    alias :href :url
    
    def get_srcs(links='img')
      begin
        links = find(links).map {|e| e.src} if links.is String
      rescue XML::Error
        links = [links]
      end
      links.map {|link| expand_link link}.uniq
    end
    
    def get_src(link='img')
      begin
        link = at(link) && at(link).src if link.is String
      rescue XML::Error; nil
      end
      expand_link link if link
    end
    
    def get_links(links='a')
      begin
        links = find(links).map {|e| e.href}.b || find(links+'//a').map {|e| e.href} if links.is String
      rescue XML::Error
        links = [links]
      end
      links.map {|link| expand_link link}.uniq
    end
    
    def get_link(link='a')
      begin
        link = at(link) && (at(link).href || at(link+'//a').href) if link.is String
      rescue XML::Error; nil
      end
      expand_link link if link
    end
    alias :get_hrefs :get_links
    alias :links :get_links
    alias :get_href :get_link
    alias :link :get_link
    alias :srcs :get_srcs
    alias :src :get_src
    
    def expand_link(link)
      case link
        when /^\w+:\/\// then link
        when /^\/\// then @loc.protocol+link
        when /^\// then @loc.root+link
        else File.join((@loc.path.b ? File.dirname(@loc.path) : @loc.root), link)
      end
    end
    
    def form(form='form', hash={}, opts={})
      form = "[action=#{@loc.path.inspect}]" if form == :self
      if form.is String
             form_node = at form
             raise XML::Error, "Can't find form by xpath `#{form}` on page #{inspect}" if !form_node or form_node.name != 'form'
      else form_node = form
      end
      hash = form_node.inputs_all.merge!(hash)
      action = expand_link(form_node.action || @loc.path)
      if form_node['method'].downcase == 'post'
        [hash, form_node.enctype =~ /multipart/, action, opts]
      else
        action = "#{action}#{action['?'] ? '&' : '?'}#{hash.urlencode}" if hash.b
        [action, opts]
      end
    end
      
    def submit(form, frame, hash={}, opts={}, &callback)
      (opts[:headers] ||= {}).Referer ||= @loc.href if @loc
      query = form(form, hash, opts)
      
      curr_target, new_target = frame.loc.href, (query[2] || query[0])
      if need_retargeting = (frame.static && curr_target != new_target)
        frame.retarget new_target
      end
      page = frame.exec(*query, &callback)
      frame.retarget curr_target, :forced if need_retargeting
      page
    end
    
    def load_scripts(frame)
      frame && frame.get_cached(*get_srcs("script[src]")).each {|js| eval_string js}
    end
    
  end

  # using reprocessing of page in case of non-200 response:
  # page_class = ReloadablePage do
  #   @res and @res.code != 200
  # end
  def ReloadablePage(&reload_condition)
    rp = Class.new Page
    rp.send :define_method, :process do |curl, opts|
      super(curl, opts || {})
      if curl.instance_eval &reload_condition
        curl.retry!
        nil # in case of reload_condition.call super's callback will not proceed
      else self
      end
    end
    rp
  end
  
end
















