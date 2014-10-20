# encoding: utf-8

# TODO 1.0+: опция для клиента, чтобы это описание имело смысл, т.к. сейчас это ложь:
#   Вызовам клиентов всегда следует ждут и возвращают обработанный ответ, если вызвваны без блока. 
#   В противном случае используется событийная модель и обработанный ответ передаётся в блок.
module RHACK

  class Client
    attr_reader :service
    attr_accessor :f
    class_attribute :frame_defaults, :instance_writer => false
    class_attribute :accounts, :instance_writer => false
    class_attribute :routes, :instance_writer => false
    
    self.frame_defaults = {}
    self.accounts = {}
    self.routes = {}
    
    class << self
    
      def inherited(child)
        child.class_eval {
          include RHACK
          __init__
        }
      end
      
    private
      
      # Set routes map
      def map(dict)
        # URI is deprecated # backward compatibility
        if defined? URI and URI.is Hash
          URI.merge! dict.map_hash {|k, v| [k.to_sym, v.freeze]}
        end
        routes.merge! dict.map_hash {|k, v| [k.to_sym, v.freeze]}
      end
      
      # Set default Frame options
      def frame(dict)
        frame_defaults.merge! dict
      end
      
      # Set usable accounts
      # @ dict : {symbol => {symbol => string, ...}}
      def accounts(dict)
        accounts.merge! dict
      end
      
    end
    
    def initialize(*args)
      service, opts = args.get_opts [:api]
      @service = service
      # first argument should be a string so that frame won't be static
      if opts.is_a?(Frame)
        @f = opts
      else
        opts = frame_defaults.merge(opts)
        if self.class.const_defined? :Result
          opts[:result] = self.class::Result
        end
        @f = Frame(route(service) || route(:login), opts)
      end
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
        
    def inspect
      "<##{self.class.self_name}:#{@service.to_s.camelize} service via #{@f.inspect}>"
    end
    
    # shortcuts to class variables #
    
    def route(name)
      routes[name]
    end
    alias :url :route
    # URI is deprecated # backward compatibility
    alias :URI :route
    
    def account(name)
      accounts[name]
    end
    
  end
  
  class ClientError < Exception; end
end
