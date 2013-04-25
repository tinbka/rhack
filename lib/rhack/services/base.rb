# encoding: utf-8

# Вызовы сервисов всегда ждут и возвращают обработанный ответ, если вызвваны без блока. 
# В противном случае используется событийная модель и обработанный ответ передаётся в блок.
module RHACK

  class Service
    attr_accessor :f
    
    def initialize(service, frame, *args)
      @service = service
      # first argument should be a string so that frame won't be static
      @f = frame || Frame(self.class::URI[service] || self.class::URI[:login], *args)
    end
    
    # Usable only for sync requests
    def login(*)
      Curl.run
      @f[0].cookies.clear
      json, wait, @f.opts[:json], @f.opts[:wait] = @f.opts[:json], @f.opts[:wait], false, true
      yield @f.get(self.class::URI[:login])
      @f.get(self.class::URI[:home]) if self.class::URI[:home]
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
  
  class ServiceError < Exception; end
  
end