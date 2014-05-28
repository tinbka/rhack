# encoding: utf-8

# TODO 1.0+: опция для клиента, чтобы это описание имело смысл, т.к. сейчас это ложь:
#   Вызовам клиентов всегда следует ждут и возвращают обработанный ответ, если вызвваны без блока. 
#   В противном случае используется событийная модель и обработанный ответ передаётся в блок.
module RHACK

  class Client
    attr_reader :service
    attr_accessor :f
    alias_constant :URI
    
    def self.inherited(child)
      child.class_eval {
        include RHACK
        __init__
      }
    end
    
    def initialize(service=:api, frame=nil, *args)
      @service = service
      # first argument should be a string so that frame won't be static
      @f = frame || Frame(URI(service) || URI(:login), *args)
    end
    
    # Usable only for sync requests
    def login(*)
      Curl.run
      @f[0].cookies.clear
      json, wait, @f.opts[:json], @f.opts[:wait] = @f.opts[:json], @f.opts[:wait], false, true
      yield @f.get(URI :login)
      @f.get(URI :home) if URI :home
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
      __send__(:"scrape_#{@service}", page)
      if url = next_url(page)
        @f.get(url) {|next_page| scrape!(next_page)}
      end
    end
        
    def inspect
      "<##{self.class.self_name}:#{@service.to_s.camelize} service via #{@f.inspect}>"
    end
    
  end
  
  class ClientError < Exception; end
end
