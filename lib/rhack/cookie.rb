# encoding: utf-8
module RHACK

  class Cookie
    __init__
    
    def initialize(*args)
      if args[1].is Scout
        str, scout = *args
        ck = str//;\s*/
        ck[1..-1].each {|par|
          a = par/'='
          case a[0].downcase
            when 'path'; @path = (a[1] == '/') ? // : /^#{Regexp.escape a[1]}/
            when 'domain'; @domain = /(^|\.)#{Regexp.escape a[1].sub(/^./, '')}$/
            when 'expires'; @expires = a[1].to_time
          end
        }
        @name, @value = ck[0].split('=', 2)
        #@value.gsub!(/^['"]|['"]$/, '')
        #L.debug args if !@domain
        (scout.cookies[scout.uri.host] ||= {})[@name] = self
      else
        @name, cookie = args[0]
        case cookie
          when Array; @value, @path, @domain = cookie
          when Hash; @value, @path, @domain = cookie.value, cookie.path, cookie.domain
          else @value = args[1].to_s
        end
      end
      @path ||= //
      @domain ||= //
      @string = "#{@name}=#{@value}; "
    end
    
    def use(str, uri)
      if !@expires or @expires > Time.now
        str << @string if uri.path[@path] and !uri.root || uri.host[@domain]
      else
        :expired
      end
    end
      
    def to_s; @value end
    def inspect; @value.inspect end
    
  end
  
end