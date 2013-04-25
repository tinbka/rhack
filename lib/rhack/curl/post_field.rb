# encoding: utf-8
module Curl
  
  class PostField
    
    def to_s
      raise "Cannot convert unnamed field to string" if !name
      display_content = if (cp = content_proc)
          cp.inspect 
        elsif (c = content)
          "#{c[0...20].inspect}#{"… (#{c.size.bytes})" if c.size > 20}"
        elsif (ln = local_name)
          File.new(ln).inspect
        end
      "#{name}=#{display_content}"
    end
    
  end
  
end