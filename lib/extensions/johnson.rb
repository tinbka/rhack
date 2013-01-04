# encoding: utf-8
module Johnson
  begin
    require 'johnson'
  rescue LoadError
    Enabled = false
  else
    if VERSION <= "2.0.0" and RUBY_VERSION > "1.9"
      Enabled = false
    else Enabled = true
    end
  end
  ### JavaScript interface DOM emulation ###
  
  class Runtime
    attr_accessor :thread_id
    Runtime_is_set = lambda {|o| !o[:eval].b or ($JSRuntime and $JSRuntime.thread_id == $CarierThread.object_id)}
    BROWSER_PATH = File.expand_path "#{File.dirname(__FILE__)}/browser"
    
    # CarierThread breaks if Multi has no work && CarierThread
    # is joined so itwon't last forever.
    #
    # Johnson is not thread safe =>
    # Runtime created in this thread will become unusable after
    # CarierThread dies. 
    #
    # So we don't use Curl.wait until Carier haven't got whole
    # request for this Runtime.
    def self.set_browser_for_curl(opts)
      if !Runtime_is_set[opts]
        if Curl.status
          Curl.recall
          $log.debug 'recalled'
        end
        if opts[:thread_safe].b
          $JSRuntime = new_browser(opts[:jq])
          $log.debug "#{$JSRuntime} initialized in #{Thread.current}\nmain: #{Thread.main}; carier: #{$CarierThread}"
        else
          $log.debug 'about to run carier'
          Curl.execute {$JSRuntime = new_browser(opts[:jq])
                            $log.debug "#{$JSRuntime} initialized in #{Thread.current}\nmain: #{Thread.main}; carier: #{$CarierThread}"}
          sleep 0.01 until Runtime_is_set[opts]
        end
      end
    end
    
    def self.new_browser(jq=false)
      rt = new
      %w{xmlw3cdom_1 xmlw3cdom_2 xmlsax env}.concat(jq ? ['jquery'] : []).each {|f|
        path = "#{BROWSER_PATH}/#{f}.js"
        rt.evaluate IO.read(path), path, 1 
      }
      rt.document = ''
      rt
    end
    
    def document=(html)
      evaluate "var document = new DOMDocument(#{html.to_doc.to_xhtml.inspect})"
    end
    
  end
  
end