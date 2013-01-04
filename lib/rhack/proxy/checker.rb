# encoding: utf-8
require 'rhack'
require File.join(File.dirname(__FILE__), 'list')

$unres_hosts = (RMTools.read('tmp/unres_hosts') or '')/"\n"

module RHACK
  module Proxy
    PROXYLISTFILE = 'log/proxylist.txt'
    DefaultGet = {:req => 'http://internet.yandex.ru/speed/?len=10&rnd=%s', :expect => {:body => "yandex! "}}
    DefaultDL = {:req => 'http://internet.yandex.ru/speed/?len=100000', :expect => {:body => "yandex! "*12500}}
    DefaultPost = {:req => [{'yandex!' => 'yandex!'}, false, 'http://internet.yandex.ru/speed/'], :expect => {:body => "hooray!"}}
      
    def DOWANT(pl, opts={})
      opts[:div] ||= 50
      opts[:timeout] ||= 5
      pc = Checker pl, opts
      begin
        pc.check
        L.info "working proxies: #{pc.wpl.size} with average ping #{pc.wpl.values.avg}"
        pc.charge pc.get_by_ping(opts[:ping] || 0.5)
        opts[:div] = opts[:dl_div] || 5
        opts[:timeout] = opts[:dl_timeout]
        pc.check opts
        L.info "fast proxies: #{pc.fpl.size} with average speed #{pc.fpl.values.avg.bytes}/s"
        pc.get_by_speed(opts[:speed] || 50000)
      rescue
        $pc = pc
        raise
      end
    end
    module_function :DOWANT

    class Interceptor < Scout
      attr_accessor :posted, :ready, :captcha, :engine, :ready, :num
    end

    class Checker
      __init__
      attr_reader :target, :opts, :pl, :ics, :wpl, :fpl
      
      def initialize(*argv)
        @pl, @target, @opts = argv.fetch_opts [[], DefaultGet]
        @wpl = {} # proxy => ping
        @fpl  = {} # proxy => Bps
        @succeed = @failed = 0
        @printer = TempPrinter self, "succeed: :succeed\nfailed : :failed"
        if @opts.page
          Curl.run
          @page = IB::Page.new(@opts.page, :rt => true, :form => true) if @opts.page.is String
          Curl.wait
          @opts.engine = @page.engine
        end
        charge @pl
      end
      
      def inspect
        "<#ProxyChecker @ics: #{@ics.size} @wpl: #{@wpl.size} @fpl: #{@fpl.size}>"
      end
      
      def charge(pl=@pl, target=@target.req)
        @ics = []
        GC.start
        fail_proc = lambda {|c, e|
          c.on_complete {}
          c.base.error = e
        }
        target = target.find_is(String) if !target.is String
        pl.each {|pr|
          sc = Interceptor.new(target, pr, $uas.rand, @opts)
          sc.http.on_failure(&fail_proc)
          @ics << sc
        }
        self
      end
      
      def check(*argv, &callback)
        target, query, opts = argv.fetch_opts [@target, @ics], @opts
        report	  = opts[:report]
        cond	    = opts[:while]
        carier	    = opts[:carier]
        post	    = opts[:post] || carier || target.is(Array)
        dl	        = opts[:dl] unless post
        division	= opts[:div]   || 500
        if !target.req.is(Array) and @page.resto target.req
          post ||= target.req == :action
          target.req = @page.host + @page.send(target.req)
        end
        if !query[0].is Interceptor
          @opts.merge!(opts)
          query = charge(query, target.req)
        end
        
        testrow = lambda {|d|
          $log << "\n#{report} = #{instance_eval(report).inspect}" if report
          throw :break if cond and !instance_eval(&cond)
          d.each {|s| 
            if post
              (carier || self).Post(s, target)
            else 
              if '%s'.in target.req
                scoped_target = target.dup
                scoped_target.req %= rand
              else
                scoped_target = target
              end
              if dl
                DL(s, scoped_target)
              else
                callback ? Get(s, scoped_target, &callback) : Get(s, scoped_target)
              end
            end
          }
          Curl.wait
        }
        
        dl ? (@fpl = {}) : (@wpl  = {})
        @succeed = @failed = 0
        Curl.execute
        catch(:break) {
          query.div(division).each {|d| testrow[d]}
        }
        catch(:break) {
          query.select {|i| i.res.is Array and i.res[0] == Curl::Err::TimeoutError}.div(division).each {|d| testrow[d]}
        }
        @printer.end!
        self
      end
      
      def expected? res, target
        target.expect[:code] ||= 200
        !target.expect.find {|k, v| !( v.is(Proc) ? v[res.__send__(k)] : v === res.__send__(k) )}
      end
      
      def DL(scout, target)
        scout.loadGet(target.req) {|c|
          res = c.res
          $log.debug "  #{c.base} returned #{res}"
          if !res.is Array and expected? res, target
            @fpl[c.proxy_url] = (res.body.size/(c.total_time - @wpl[scout.proxystr].to_f)).to_i
            @succeed += 1
          else 
            @failed += 1
          end
          @printer.p if !$panic
        }
      end
    
      def Get(scout, target, &callback)
        if callback
          scout.loadGet(target.req, &callback)
        else
          scout.loadGet(target) {|c|
            res = c.res
            $log.debug " #{c.base} returned #{res}"
            if !res.is Array and expected? res, target
              @wpl[c.proxy_url] = c.total_time
              @succeed += 1
            else 
              @failed += 1
            end
            @printer.p if !$panic
         }
        end
      end
      
      def Post(scout, target)
        scout.loadPost(*target.req) {|c|
          res = c.res
          $log.debug "#{c.base} returned #{res}"
          if !res.is Array and expected? res, target# || (res.code == '303' and @opts.engine.is IB::Wakaba)
            @wpl[c.proxy_url] = c.total_time
            @succeed += 1
          else 
            @failed += 1
          end
          @printer.p if !$panic
        }
      end
      
      def to_a
        deprecation "use #to_pl instead."
        to_pl
      end
    
      def to_pl
        @wpl.map {|k,v| [v,k]}.sort.map! {|e| e.last/':'}.to_pl
      end
      
      def fastest
        val = @wpl.values.sort[0]
        @wpl.find {|k,v| v == val}[0]/':' if val
      end
    
      def get_by_ping(limit, minlen=1)
        newpl = []
        case limit
          when Numeric;   @wpl.each {|pr,lt| newpl << pr/':' if lt < limit}
          when Range 
            begin
              limit.to_a.each {|i|
                @wpl.each {|pr,lt| newpl << pr/':' if lt < i}
                break if newpl.size >= minlen
                newpl.clear
              }
            rescue TypeError
              @wpl.each {|pr,lt| newpl << pr/':' if lt < limit.min}
              if newpl.size < minlen
                newpl.clear
                @wpl.each {|pr,lt| newpl << pr/':' if lt < limit.max}
              end
            end
        end
        newpl.to_pl
      end
      
      def get_by_speed(min)
        newpl = []
        @fpl.each {|pr, sp| newpl << pr/':' if sp >= min}
        newpl.to_pl
      end
      
    end
        
  end
end