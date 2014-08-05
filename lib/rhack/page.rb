# encoding: utf-8
class Object
  unless defined? one_argument_is_a?
    alias :one_argument_is_a? :is_a? 
    def is_a?(class1, *other_classes)
      one_argument_is_a? class1 or other_classes.any? {|cl| one_argument_is_a? cl}
    end
  end
end

module RHACK
        
  class JsonString < String
    __init__
    attr_reader :source
    
    def initialize(source)
      @source = source
      super source.to_json
    end
    
    def inspect
      "#<RHACK::JsonString(#{@source.inspect})>"
    end
  end
      
  class ScrapeError < ArgumentError; end
  class NodeNotFound < ScrapeError; end

  # Frame( ScoutSquad( Curl::Multi <- Scout( Curl API ), Scout, ... ) ) => 
  # Curl -> Johnson::Runtime -> XML::Document => Page( XML::Document ), Page, ... 
  class Page
    # for debug, just enable L#debug, don't write tons of chaotic log-lines 
    __init__
    attr_writer :title
    attr_reader :body, :loc, :data, :doc, :js, :curl, :curl_res, :failed
    alias :hash :data # DEPRECATED
    alias :html :body # DEPRECATED
    
    # result of page processing been made in frame context
    attr_accessor :res
    # for johnson
    @@ignore = /google|_gat|tracker|adver/i
      
      # Frame calls it with no args
    def initialize(obj='', loc=Hash.new(''), js=is_a?(HtmlPage)&&(Johnson::Runtime.browser||Johnson::Runtime.new))
      loc = loc.parse:uri if !loc.is Hash
      @js = js
      if obj.is Curl::Easy or obj.kinda Scout
        c = obj.kinda(Scout) ? obj.http : obj
        # just (c, loc) would pass to #process opts variable that returns '' on any key
        process(c, loc.b || {})
      else
        @body = obj
        @loc = loc
      end
    end
    
    def empty?
      !@data && !@body.b
    end
    
    def size
      if @data.nil?
        (@body || '').size
      elsif @data == false
        0
      else
        @data.inspect.size
      end
    end
        
    def inspect
      sz = size
      if !@data.nil?
        "<##{self.class.name} (#{@data == false ? 'failed to parse' : sz.bytes}) #{@json ? 'json' : 'url params'}>"
      else
        "<##{self.class.name} #{sz == 0 ? '(empty)' : "#{@failed ? @curl_res.header : '«'+title(false)+'»'} (#{sz.bytes})"}#{' js enabled' if @js and @doc}>"
      end
    end
    
    def utf!
      @body.utf!
    end
    
    def url
      @loc.href
    end
    alias :href :url
    
    
    # override this in a subclass
    def failed?(*)
      @curl_res.code != 200
    end
    
    # override this in a subclass
    def retry?(*)
      false
    end
    
    # override this in a subclass
    # MUST return self if successful
    # MAY return false otherwise
    def parse(opts={})
      if failed?
        failed!
        if opts[:json] or opts[:hash]
          @data = false
        end
        return self
      end
      
      if opts[:json]
        parse_json opts
      elsif opts[:hash]
        parse_hash opts
      elsif opts[:xml]
        parse_xml opts
      else
        parse_html opts
      end
      
      self
    end
    
  private
    
    def failed!
      @body = @curl_res.body
      @failed = @curl_res.code
    end
    
    def log_failed(action)
      L.debug "Failed #{action} from #{@curl.last_effective_url}, take a look at my @body for info; my object_id is #{object_id}"
    end
    
    def parse_xml(*)
      @body = @curl_res.body.xml_to_utf
      to_xml
    rescue StandardError => e
      L.warn "Exception raised during `to_xml': #{e.inspect}"
      log_failed "to parse page as XML"
      failed!
    end
    
    def parse_html(opts={})
      @body = @curl_res.body.xml_to_utf
      to_html
      if opts[:eval]
        load_scripts opts[:load_scripts]
        eval_js
      end
    rescue StandardError => e
      L.warn "Exception raised during `to_html': #{e.inspect}"
      log_failed "to parse page as HTML"
      failed!
    end
      
    def parse_json(*)
      @json = true
      begin
        @data = @curl_res.body.from_json
      rescue StandardError => e
        L.warn "Exception raised during `from_json': #{e.inspect}"
      end
      if !@data or @data.is String
        log_failed "to get JSON"
        failed!
        @data = false
      end
    end
    
    def parse_hash(*)
      if @curl_res.body.inline
        @data = @curl_res.body.to_params
      else
        log_failed "to get url-params hash"
        failed!
        @data = false
      end
    end
    
  public
    
    # We can then alternate #process in Page subclasses
    # Frame doesn't mind about value returned by #process
    def process(c, opts={})
      @loc = c.last_effective_url.parse:uri
      @curl = c
      @curl_res = c.res
      
      if retry?
        c.retry!
        return # callback will not proceed
      end
      
      L.debug "#{@loc.fullpath} -> #{@curl_res}"
      parse(opts)
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
      L.debug "#{@js} evaluating in #{Thread.current}\nmain: #{Thread.main}; carier: #{Curl.carier_thread}"
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
    
    def to_html
      @doc = @body.to_html
    end
    
    def to_xml
      @doc = @body.to_xml
    end
    
    def title(full=true)
      if @data.nil? and !@failed and @body.b
        if full
          to_html unless defined? @doc
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
    
    
    # HELPERS #
    
    # hook to create even-looked lines defining a hash in my Verdana 10px, e.g.
    # dict key1: value1, ...
    #       key2: value2, ...
    def dict(hash)
      hash.is_a?(Hash) ? hash : Hash[hash]
    end
    
    # maps {'firstname lastname' => tuple} into {:firstname => tuple[0], :lastname => tuple[1]}
    def flatten_dict(hash)
      result = {}
      hash.each {|k, v|
        if k.is String and k[' ']
          k.split(' ').each_with_index {|k_unit, k_idx|
            result[k_unit.to_sym] = v[k_idx]
          }
        elsif k.is Array
          k.each_with_index {|k_unit, k_idx|
            result[k_unit.to_sym] = v[k_idx]
          }
        else
          result[k.to_sym] = v
        end
      }
      result
    end
    
    # makes a relative path being on this page into an absolute path
    def expand_link(link)
      case link
        when /^\w+:\/\// then link
        when /^\/\// then @loc.protocol + ':' + link
        when /^\// then @loc.root + link
        when /^\?/ then File.join(@loc.root, @loc.path) + link
        when /^#/ then File.join(@loc.root, @loc.fullpath) + link
        else File.join @loc.root, File.dirname(@loc.path), link
      end
    end
    
    
    # FINDERS #
      
  private
      
    def node_is_missing!(selector, options)
      missing = options[:missing]
      if missing.is Proc
        missing.call(selector)
      elsif missing
        if missing.is String
          message %= {selector: selector}
        end
        raise NodeNotFound, missing
      end
    end
      
    def preprocess_search_result(preresult, preprocess)
      if preprocess.is_a? Proc
        preprocess.call(preresult)
      elsif preprocess.is_a? Symbol
        __send__(preprocess, preresult)
      else
        preresult
      end
    end
      
    def preprocess_search_results(preresult, preprocess)
      if preprocess.is_a? Proc
        preresult.map(&preprocess)
      elsif preprocess.is_a? Symbol
        preresult.map {|node| __send__(preprocess, node)}
      else
        preresult
      end
    end
    
    def __at(xp) (@doc || to_html).at xp end
    
    def __find(xp) (@doc || to_html).find xp end
    
  public
    
    def at(selector_or_node, options={})
      if selector_or_node and preresult = selector_or_node.is_a?(LibXML::XML::Node) ? 
          selector_or_node : __at(selector_or_node)
          
        preresult = preprocess_search_result(preresult, options[:preprocess])
        block_given? ? yield(preresult) : preresult
      else
        node_is_missing!(selector_or_node, options)
        preresult
      end
    end
    alias :first :at
    
    def find(selector_or_nodes, options={}, &foreach)
      preresult = selector_or_nodes.is_a?(LibXML::XML::XPath::Object, Array) ?
        selector_or_nodes : __find(selector_or_nodes)
        
      if preresult.size > 0
        preresult = preprocess_search_results(preresult, options[:preprocess])
        foreach ? preresult.each(&foreach) : preresult
      else
        node_is_missing!(selector_or_nodes, options)
        preresult
      end
    end
    alias :all :find
    
    
    # FINDERS PREPROCESSORS #
    
    def text(selector_or_node, options={})
      if node = at(selector_or_node, options)
        txt = node.text.strip
        block_given? ? yield(txt) : txt
      end
    end
    
    def texts(hash, options={})
      hash.map_values {|selector_or_node|
        text(selector_or_node, options)
      }
    end
    
    def get_src(selector_or_node='img', options={}, &onfound)
      at(selector_or_node, options.merge(:preprocess => lambda {|node|
        if src = node.src
          expand_link src
        end
      })) {|src| onfound && src ? onfound.call(src) : src}
    end
    alias :src :get_src
    
    def get_link(selector_or_node='a', options={}, &onfound)
      at(selector_or_node, options.merge(:preprocess => lambda {|node|
        unless href = node.href
          if node = node.find('a')
            href = node.href
          end
        end
        if href
          expand_link href
        end
      })) {|href| onfound && href ? onfound.call(href) : href}
    end
    alias :link :get_link
    alias :get_href :get_link
    
    def map(selector_or_nodes, options={}, &mapper)
      mapping = find(selector_or_nodes, options.merge(:preprocess => mapper))
      unless options[:compact] == false
        mapping = mapping.to_a.compact
      end
      mapping
    end
    
    def map_json(selector_or_nodes, options={}, &mapper)
      JsonString map(selector_or_nodes, options, &mapper)
    end
    
    
    # FORMS #
    
    def form(form='form', hash={}, opts={})
      form = "[action=#{@loc.path.inspect}]" if form == :self
      if form.is String
             form_node = at form
             raise LibXML::XML::Error, "Can't find form by xpath `#{form}` on page #{inspect}" if !form_node or form_node.name != 'form'
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
    
    
    ### DEPRECATED ###
    
    # TODO: make into same form as #get_src and #map
    def get_srcs(links='img')
      begin
        links = find(links).map {|e| e.src} if links.is String
      rescue LibXML::XML::Error
        links = [links]
      end
      links.map {|link| expand_link link}.uniq
    end
    alias :srcs :get_srcs
    
    #def get_src(link='img')
    #  begin
    #    link = at(link) && at(link).src if link.is String
    #  rescue LibXML::XML::Error; nil
    #  end
    #  expand_link link if link
    #end
    
    def get_links(links='a')
      begin
        links = find(links).map {|e| e.href}.b || find(links+'//a').map {|e| e.href} if links.is String
      rescue LibXML::XML::Error
        links = [links]
      end
      links.map {|link| expand_link link}.uniq
    end
    alias :get_hrefs :get_links
    alias :links :get_links
    
    #def get_link(link='a')
    #  begin
    #    link = at(link) && (at(link).href || at(link+'//a').href) if link.is String
    #  rescue XML::Error; nil
    #  end
    #  expand_link link if link
    #end
    
    def load_scripts(frame)
      frame && frame.get_cached(*get_srcs("script[src]")).each {|js| eval_string js}
    end
    
  end
  
  ### Pages with specific processing
  
  class XmlPage < Page
    __init__
    
    # override this in a subclass
    # MUST return self if successful
    # MAY return false otherwise
    def parse(opts={})
      if failed?
        failed!
      else
        parse_xml opts
      end
      self
    end
    
  end
  
  
  class HtmlPage < Page
    __init__
    
    # override this in a subclass
    # MUST return self if successful
    # MAY return false otherwise
    def parse(opts={})
      if failed?
        failed!
      else
        parse_html opts
      end
      self
    end
    
  end
  
  
  class JsonPage < Page
    __init__
    
    # override this in a subclass
    # MUST return self if successful
    # MAY return false otherwise
    def parse(opts={})
      if failed?
        failed!
      else
        parse_json opts
      end
      self
    end
    
  end
  
  
  class HashPage < Page
    __init__
    
    # override this in a subclass
    # MUST return self if successful
    # MAY return false otherwise
    def parse(opts={})
      if failed?
        failed!
      else
        parse_hash opts
      end
      self
    end
    
  end

  ### DEPRECATED ### Use native inheritance and override #retry instead
  
  # using reprocessing of page in case of non-200 response:
  # page_class = ReloadablePage do
  #   @res and @res.code != 200
  # end
  def ReloadablePage(&reload_condition)
    Class.new Page do
      define_method :process do |curl, opts|
        super(curl, opts || {})
        if curl.instance_eval &reload_condition
          curl.retry!
          nil # in case of reload_condition.call super's callback will not proceed
        else self
        end
      end
    end
  end
  
end