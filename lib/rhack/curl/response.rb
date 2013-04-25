# encoding: utf-8
module Curl
  
  class Response
    __init__
    attr_reader :header, :code, :body, :hash, :timestamp, :time, :req, :date, :error
    
    def to_s
      str = '<#'
      if @error
        str << "#{@error[0].self_name}: #{@error[1]}"
      else
        str << (@header[/\d{3}/] == @code.to_s ? @header : "#{@header[/\S+/]} #{@code}") if @header
        if @hash.location
          str << ' '+@req.url if $panic
          str << ' -> '+@hash.location 
        end
        str << " (#{@body ? @body.size.bytes : 'No'} Body)"
        str << " [#{@timestamp}]" if @timestamp
      end
      str << '>'
    end
    alias :inspect :to_s
    
    def initialize(easy)
      @hash = {}
      @timestamp = @date = @header = nil
      if easy.base.error
        @error = easy.base.error
      else
        if headers = easy.header_str || easy.base.headers
          headers /= "\r\n"
          @header = headers.shift
          headers.each {|h|
            h /= ': '
            if h[0]
              h[0].downcase!
              if h[0] == 'set-cookie'
                (@hash.cookies ||= []) << h[1]
              else
                @hash[h[0]] = h[1]
              end
            end
          }
          @timestamp = if @hash.date
              begin
                @date = @hash.date.to_time
              rescue => e
                (@date = Time.now).strftime("%H:%M:%S")
                L < "Error #{e.class}:#{e.message} with @hash.date = #{@hash.date.inspect}"
              end
              @hash.date[/\d\d:\d\d:\d\d/]
            else
              (@date = Time.now).strftime("%H:%M:%S")
            end
        end
        @code	= easy.response_code
        @body	= easy.body_str 
        @time	= easy.total_time
      end
      
      @req = {}
      @req.url	        = easy.last_effective_url
      @req.headers	= easy.headers
      if range = easy.headers.Range and range[/(\d+)-(\d+)/]
        @req.range   = $1.to_i .. $2.to_i
      end
      if easy.base and @req.meth = easy.base.last_method and @req.meth == :post
        @req.body	  = easy.post_body
        @req.mp	    = easy.multipart_form_post?
      end
    end
    
    def is(klass)
      if @error
        klass == Array || klass = Curl::Response
      else
        klass == Curl::Response
      end
    end
  
    def [](key_or_index)
      @error ? @error[key_or_index] : @hash[key_or_index.downcase]
    end
    
    alias :headers :hash
  end
  
end