# encoding: utf-8
module RHACK

  class Client
    attr_reader :service
    attr_accessor :f
    class_attribute :frame_defaults, :instance_writer => false
    class_attribute :scouts_initializers, :instance_writer => false
    class_attribute :accounts, :instance_writer => false
    class_attribute :routes, :instance_writer => false
    class_attribute :rootpath, :instance_writer => false
    
    self.frame_defaults = {}
    self.scouts_initializers = []
    self.accounts = {}
    self.routes = {}
    
    class << self
    
      def inherited(child)
        child.class_eval do
          include RHACK
          __init__
          
          # Proxying Rails router methods digging into the client namespace
          if defined? ::Rails.application.routes.url_helpers
            url_helpers = ::Rails.application.routes.url_helpers
            routes_namespace = name.gsub(/::/, '').underscore.sub(/_client$/, '')
            route_pattern = /^(.+_)?#{routes_namespace}_(.+)/
            url_helpers.my_methods.each {|name|
              if name.to_s[route_pattern]
                full_route_name = $&
                define_method "#$1#$2" do |*options|
                  url_helpers.send full_route_name, *options
                end
              end
            }
          end
        end
      end
      
      def method_missing(method, *args, &block)
        if personal_instance_methods.include? method
          return new.__send__(method, *args, &block)
        end
        super
      end
      
    private
      
      def root(value=nil)
        if value
          value = 'http://' + value if value !~ /^\w+:/
          self.rootpath = value
        else
          self.rootpath
        end
      end
      alias :host :root
      
      # Set routes map
      def map(dict)
        # URI is deprecated # backward compatibility
        if defined? URI and URI.is Hash
          URI.merge! dict.map_hash {|k, v| [k.to_sym, v.freeze]}
        end
        self.routes += dict.map_hash {|k, v| [k.to_sym, v.freeze]}
      end
      
      # Set default Frame options
      def frame(dict, &scout_initializer)
        self.frame_defaults += dict
        if scout_initializer
          self.scouts_initializers << scout_initializer
        end
      end
      
      # Set usable accounts
      # @ dict : {symbol => {symbol => string, ...}}
      def accounts(dict)
        self.accounts += dict
      end
      
    end
    
    def initialize(*args)
      service, opts = args.get_opts [routes.include?(:api) ? :api : nil]
      @service = service # Deprectated. Use different classes to implement different services.
      # first argument should be a string so that frame won't be static
      if opts.is_a?(Frame)
        @f = opts
      else
        opts = frame_defaults.merge(opts)
        if self.class.const_defined? :Result
          opts[:result] = self.class::Result
        end
        if scouts_initializers = self.scouts_initializers.presence
          opts[:on_scout_initialize] ||= lambda {|scout|
            scouts_initializers.each {|initializer|
              initializer.call scout
            }
          }
        end
        @f = Frame(rootpath || route(service) || route(:login), opts)
      end
    end
        
    def inspect
      "<##{self.class.name}#{":#{@service.to_s.camelize} service" if @service} via #{@f.inspect}>"
    end
    
    
    # Usable only for sync requests
    def login(*)
      Curl.run
      @f[0].cookies.clear
      json, wait, @f.opts[:json], @f.opts[:wait] = @f.opts[:json], @f.opts[:wait], false, true
      yield @f.get(route :login)
      @f.get(route :home) if route :home
      @f.opts[:json], @f.opts[:wait] = json, wait
      @f.copy_cookies!
    end
      
    def go(*args, &block)
      __send__(@service, *args, &block) 
    rescue
      L < $!
      Curl.reload
    end
    
    
    
    def scrape!(page)
      __send__(:"scrape_#@service", page)
      if url = next_url(page)
        @f.get(url) {|next_page| scrape!(next_page)}
      end
    end
    
    
    # shortcuts to class variables #
    
    def route(name, interpolation=nil)
      if url = routes[name]
        if interpolation
          url %= interpolation.symbolize_keys
        end
        if url !~ /^\w+:/
          url = File.join rootpath, url
        end
        url
      end
    end
    alias :url :route
    
    def account(name)
      accounts[name]
    end
    
  end
  
end
