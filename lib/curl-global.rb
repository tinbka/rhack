# encoding: utf-8
module Curl
  
  def execute(unless_allready=false)
    if unless_allready and Curl.status
      return L.debug "Non-nil status! Avoid executing"
    end
    if $CarierThread and s = $CarierThread.status
      L.debug "Carier thread allready started and has status #{s}"
    else
      if s = Curl.status(false) then L.warn s end
      L.debug($CarierThread ? "Resetting Carier thread" : "Setting Carier thread up")
      $CarierThread = Thread.new {
        error = nil
        begin
          # "why Thread#value is raising since it never raised before?"
          yield if block_given?
        rescue => error
          nil
        end
        loop {
          begin
              # with true argument (idle) it would break only if no requests to perform
            break unless $Carier.perform true
            L.debug "Nothing to perform; idling..."
          rescue => error
            break
              # but ruby mystically crashes if next sequence occur:
              # Multi performs and can't see any requests so entering idle mode
              # we add some requests and multi load them
              # one of requests' callbacks raises error in *main* thread
              # so we can't allow any raises here, instead, keep them in 'wait' section
          end
        } unless error
        error
      }
      # until main thread has sleep a bit, $CarierThread will have status "run", 
      # no matter whether it's idling or performing requests
      sleep 0.001
    end
  end
  alias :run :execute
  module_function :execute, :run
  
  def wait
    if $CarierThread and $CarierThread.status
      if !(within = Thread.current == $CarierThread)
        # We can't set `perform' timeout lesser than 1 second in the curl binding
        # because in that case thread status would always be "run"
        # so here we wait for exactly 1 sec
        sleep 1 
      end
      # Also, if thread do Kernel.sleep, it would skip Curl.wait here
      if !$Carier.sheduled and ($CarierThread.status == 'sleep' or within && $Carier.reqs.empty?)
        L.debug "No shedule to wait"
      else
        L.log "Waiting for Carier to complete in #{within ? 'it\'s thread' : Thread.main == Thread.current ? 'main thread' : 'thread '+Thread.current.object_id}"
        begin
          L.log { "Trying to change $CarierThreadIsJoined #{$CarierThreadIsJoined} -> true from #{within ? 'it\'s thread' : Thread.main == Thread.current ? 'main thread' : 'thread '+Thread.current.object_id}" }
          if within 
            L.debug "calling this from one of callbacks to wait for the rest to complete"
            begin
              $Carier.perform
            rescue RuntimeError => e
              L.warn [e, e.message]
              L.info "$Carier $Carier.sheduled $CarierThread $CarierThread.status", binding
              L.warn "Failed to run Multi#perform: nothing to perform"
            end
          else 
            $CarierThreadIsJoined = true
            $CarierThread.join
          end
        rescue (defined?(IRB) ? IRB::Abort : NilClass)
          recall!
          L.info "Carier thread recalled by keyboard"
        ensure
          L.log "trying to change $CarierThreadIsJoined #{$CarierThreadIsJoined} -> false from #{within ? 'it\'s' : 'main'} thread"
          if !within
            $CarierThreadIsJoined = false
            if $CarierThread and e = $CarierThread.value
              # this will raise thread-safely in main thread
              # in case of unrescued error in CarierThread
              recall!
              raise e 
            end
            execute
          end
        end
      end
    else
      L < "No thread to wait. I guess I should create one"
      execute
      wait
    end
  end
  module_function :wait
  
  def recall
    L.debug caller
    if $CarierThread
      L.debug "Recalling Carier thread"
      $CarierThread.kill
      sleep 1
    else
      L.debug "No thread to recall"
    end
  end
  alias :stop :recall
  
  def recall!
    if $CarierThread
      L.info "Recalling thread and resetting Carier!!!"
      $CarierThread.kill
      $CarierThread = nil
      $Carier.reset
    else
      L.debug "No thread to recall!"
    end
  end
  alias :stop! :recall!
  module_function :recall!, :stop!, :recall, :stop
  
  def reset
    recall
    execute
  end
  alias :reload :reset
  
  def reset!
    recall!
    execute
  end
  alias :reload! :reset!
  module_function :reset!, :reset, :reload!, :reload
  
  def status(raise_e=true)
    if $CarierThread and (s = $CarierThread.status)
      L.log "Carier thread responding with status #{s}"
      s
    elsif $CarierThread
      if e = $CarierThread.value
        if raise_e
          recall!
          raise e
        else
          L.log "Carier Thread returned #{e.inspect}"
          e
        end
      else
        L.debug "Carier Thread is exited without error"
      end
    else
      L.debug "There is no Carier Thread atm"
    end
  end
  alias :st :status
  module_function :status, :st
  
end