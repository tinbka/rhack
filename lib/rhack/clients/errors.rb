module RHACK
    
  # Abstraction, don't use it.
  class BasicError < StandardError
    # keep here debugful data
    attr_accessor :details
    
    # # Usage ...
    # # ... without :details keyword, as usual:
    # raise ServerError, 'an error has occured'
    # # ... with :details keyword
    # raise ServerError.new 'an error has occured', details: @curl_res
    # # ... if you also want to set custom backtrace
    # raise ServerError.new('an error has occured', details: @curl_res), backtrace_array
    def initialize(message, *opts) # details: nil
      @details = opts.extract_options![:details]
      super
    end
    
  end
  
  # The client couldn't connect and yet we don't know whose this fault is,
  # e.g. domain lookup error or timeout.
  class ConnectionError < BasicError; end
  
  # The client successfully connected to the server
  # but it returned an improper, non-descriptive response,
  # e.g. 500 status, empty body, etc.
  class ServerError < BasicError; end
  
  # The client successfully connected to the server
  # but server didn't accept a request and returned a descriptive exception,
  # e.g. 406 status, body with only "error" key, etc.
  class RequestError < BasicError; end
  
  # The client successfully connected to the server,
  # the server accept a request but we failed to process a response,
  # e.g. because of an unexpected response structure
  class ClientError < BasicError; end
    
end