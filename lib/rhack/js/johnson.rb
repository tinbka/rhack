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
    cattr_accessor :browser
    attr_accessor :thread_id
    BROWSER_PATH = File.expand_path "../browser", __FILE__
    
    class << self
      
      def runtime_set?(opts)
        !opts[:eval].b or (@@browser and @@browser.thread_id == Curl.carier_thread.object_id)
      end
    
      # CarierThread breaks if Multi has no work && CarierThread
      # is joined so itwon't last forever.
      #
      # Johnson is not thread safe =>
      # Runtime created in this thread will become unusable after
      # CarierThread dies. 
      #
      # So we don't use Curl.wait until Carier haven't got whole
      # request for this Runtime.
      def set_browser_for_curl(opts)
        unless runtime_set? opts
          if Curl.status
            Curl.recall
            Curl.debug 'recalled'
          end
          if opts[:thread_safe].b
            @@browser = new_browser(opts[:jq])
            L.debug "#@@browser initialized in #{Thread.current}\nmain: #{Thread.main}; carier: #{Curl.carier_thread}"
          else
            L.debug 'about to run carier'
            Curl.execute {@@browser = new_browser(opts[:jq])
                               L.debug "#@@browser initialized in #{Thread.current}\nmain: #{Thread.main}; carier: #{Curl.carier_thread}"}
            sleep 0.01 until runtime_set? opts
          end
        end
      end
    
      def new_browser(jq=false)
        rt = new
        %w{xmlw3cdom_1 xmlw3cdom_2 xmlsax env}.concat(jq ? ['jquery'] : []).each {|f|
          path = "#{BROWSER_PATH}/#{f}.js"
          rt.evaluate IO.read(path), path, 1 
        }
        rt.document = ''
        rt
      end
    
    end
    
    def document=(html)
      evaluate "var document = new DOMDocument(#{html.to_doc.to_xhtml.inspect})"
    end
    
  end
  
end