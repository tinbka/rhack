# encoding: utf-8
class << Curl
  
  def execute(unless_allready=false)
    if unless_allready and status
      return L.log "Non-nil status! Avoid executing"
    end
    if @@carier_thread and s = @@carier_thread.status
      L.log "Carier thread allready started and has status #{s}"
    else
      if s = status(false) then L.warn s end
      L.log(@@carier_thread ? "Resetting Carier thread" : "Setting Carier thread up")
      @@carier_thread = thread {
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
            break unless @@carier.perform true
            L.log "Nothing to perform; idling..."
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
  
  def wait
    if @@carier_thread and @@carier_thread.status
      unless within = Thread.current == @@carier_thread
        # We can't set `perform' timeout lesser than 1 second in the curl binding
        # because in that case thread status would always be "run"
        # so here we wait for exactly 1 sec
        sleep 1 
      end
      # Also, if thread do Kernel.sleep, it would skip Curl.wait here
      if !@@carier.sheduled and (@@carier_thread.status == 'sleep' or within && @@carier.reqs.empty?)
        L.log "No shedule to wait"
      else
        this_thread = within ? 'it\'s thread' : Thread.main == Thread.current ? 'main thread' : 'thread '+Thread.current.object_id
        L.log "Waiting for Carier to complete in #{this_thread}"
        begin
          L.log { "Trying to change Curl.joined #@@joined -> true from #{this_thread}" }
          if within 
            L.log "calling this from one of callbacks to wait for the rest to complete"
            begin
              @@carier.perform
            rescue RuntimeError => e
              L.warn [e, e.message]
              L.info "@@carier @@carier.sheduled @@carier_thread @@carier_thread.status", binding
              L.warn "Failed to run Multi#perform: nothing to perform"
            end
          else 
            @@joined = true
            @@carier_thread.join
          end
        rescue (defined?(IRB) ? IRB::Abort : NilClass)
          recall!
          L.info "Carier thread recalled by keyboard"
        ensure
          L.log "trying to change Curl.joined #@@joined -> false from #{this_thread}"
          if !within
            @@joined = false
            # using Curl#execute from different threads may cause problems here when you don't control input,
            # for example, in a daemonized ruby process
            # just do not get $CarierThread joined from non-main thread
            if @@carier_thread and e = @@carier_thread.value
              # this will raise thread-safely in main thread
              # in case of unrescued error in CarierThread
              L.log(([e.message]+RMTools.format_trace(e.backtrace))*"\n")
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
  
  def recall
    L.debug caller
    if @@carier_thread
      L.log "Recalling Carier thread"
      @@carier_thread.kill
      sleep 1
    else
      L.log "No thread to recall"
    end
  end
  alias :stop :recall
  
  def recall!
    if @@carier_thread
      L.warn "Recalling thread and resetting Carier!!!"
      @@carier_thread.kill
      @@carier_thread = nil
      reset_carier!
      @@carier.reset
    else
      L.log "No thread to recall!"
    end
  end
  alias :stop! :recall!
  
  def reset_carier!
    @@carier.clear!
    @@carier = Multi.new
    carier.pipeline = true
    #GC.start
  end
  
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
  
  def status(raise_error=true)
    if @@carier_thread and (s = @@carier_thread.status)
      L.log "Carier thread responding with status #{s}"
      s
    elsif @@carier_thread
      begin
        error = @@carier_thread.value
      rescue => error
        L.warn "Carier thread has raised"
        if raise_error
          recall!
          raise error
        else
          L.log "Carier Thread has catched #{error.inspect}"
          error
        end
      else
        L.log "Carier Thread has exited without error"
      end
    else
      L.log "There is no Carier Thread atm"
    end
  end
  alias :st :status
  
end