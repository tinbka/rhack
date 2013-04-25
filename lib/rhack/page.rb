# encoding: utf-8
module RHACK

    # Frame( ScoutSquad( Curl::Multi <- Scout( Curl API ), Scout, ... ) ) => 
    # Curl -> Johnson::Runtime -> XML::Document => Page( XML::Document ), Page, ... 
    
    class Page
    # for debug, just enable L#debug, don't write tons of chaotic log-lines 
    __init__
    attr_writer :title
    attr_reader :html, :loc, :hash, :doc, :js, :curl_res, :failed
    # result of page processing been made in frame context
    attr_accessor :res
    # for johnson
    @@ignore = /google|_gat|tracker|adver/i
      
    def initialize(obj='', loc=Hash.new(''), js=Johnson::Runtime.browser||Johnson::Runtime.new)
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