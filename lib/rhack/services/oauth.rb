# encoding: utf-8
module RHACK
  
  class OAuthError < ClientError; end
  class StateError < OAuthError; end
  class NoTokenError < OAuthError; end
  
  class CodeIndiffirentPage < Page
    def process(c, opts={})
      c.res.instance_variable_set :@code, 200
      super
    end
  end
  
  class OAuthClient < Client
    attr_reader :oauth_tokens
    
    # just a buffer for one action
    # @ {user_id => hash<last used user data>}
    attr_accessor :users_data
    
    def initialize *args
      @users_data = {}
      @oauth_tokens = {}
      @oauth_states_users = {}
      @storage = self.class.storage
      service, frame, opts = args.get_opts [:api, nil], {}
      super service, frame, {cp: false, wait: true, json: true, scouts: 1}.merge(opts)
    end
    
    alias_constant :OAUTH
    alias_constant :API
    
    # TODO: 
    # * hierarchical url_params[:scope] (?)
    def validate(user_id, url_params={})
      if action = url_params.delete(:action)
        if action_params = API(action)
          url_params = action_params.slice(:scope).merge(url_params)
        end
      end
      if data = user_data([user_id, url_params[:scope]])
        token, expires = data
        if user_id != '__app__'
          if token and expires
            # substracting a minute so that "last moment" request wouldn't fail
            if expires - 60 < Time.now.to_i
              token = false
            end
          else
            token = false
          end
        end
      end
      if token
        block_given? ? yield(token) : token
      else
        {oauth_url: get_oauth_url(user_id, url_params)}
      end
    end
    
    # @ state_params : [string<user_id>, (strings*",")<scope>]
    # persistent: state_params -> [string<token>, int<expires>]
    def user_data(state_params, data=nil)
      key = "#{self.class.name.sub('RHACK::', '').underscore}:tokens"
      if data
        if data == :clear
          @oauth_tokens.delete state_params
          $redis.hdel key, state_params*':'
        else
          @oauth_tokens[state_params] = data
          $redis.hset key, state_params*':', data*','
        end
      elsif !@oauth_tokens[state_params]
        if data = $redis.hget(key, state_params*':')
          token, expire = data/','
          @oauth_tokens[state_params] = [token, expire.to_i]
        end
      end
      @users_data[state_params[0]] = @oauth_tokens[state_params]
    end
    
    # usually called internally
    def get_oauth_url(user_id='__default__', url_params={})
      state = String.rand(64)
      @oauth_states_users[state] = [user_id, url_params[:scope]]
      # TODO: change it with something more consious
      url_params[:redirect_uri] = OAUTH(:landing).dup
      L.debug url_params
      if redirect_protocol = url_params.delete(:redirect_protocol)
        url_params[:redirect_uri].sub!(/^\w+/, redirect_protocol)
      end
      L.debug url_params
      @oauth_url = URI(:oauth)[:auth] + {
        response_type: 'code', 
        client_id: OAUTH(:id),
        state: state
      }.merge(url_params).to_params
    end
    
    # @ url_params : {:code, :state, ...}
    def get_oauth_token(url_params={}, &block)
      state = url_params.delete :state
      L.debug state
      if state_params = @oauth_states_users[state]
        if data = user_data(state_params)
          # code is allready used, return token
          return data[0]
        end
      else
        raise StateError, "Couldn't find user authentication state. Please, retry authorization from start"
      end
      
      url_params[:redirect_uri] = OAUTH(:landing).dup
      L.debug url_params
      if redirect_protocol = url_params.delete(:redirect_protocol)
        url_params[:redirect_uri].sub!(/^\w+/, redirect_protocol)
      end
      L.debug url_params
      @f.run({}, URI(:oauth)[:token] + {
        grant_type: 'authorization_code',
        client_id: OAUTH(:id), 
        client_secret: OAUTH(:secret)
      }.merge(url_params).to_params, raw: true, proc_result: block) {|curl|
        L.debug curl.res
        L.debug curl.res.body
        # TODO: refactor parse type selector: raw, json, hash, xml...
        # from_json -> (symbolize_keys: true)
        if curl.res.code == 200
          body = curl.res.body
          hash = '{['[body[0]] ? body.from_json(symbolize_keys: true) : body.to_params
          token = hash.access_token
          data = [token, Time.now.to_i + (hash.expires || hash.expires_in).to_i]
          L.debug token
          user_data(state_params, data)
          token
        else
          raise OAuthError, curl.res.body
        end
      }
    end
    
    def get_application_oauth_token(&block)
      @f.run(URI(:oauth)[:token] + {
        grant_type: 'client_credentials',
        client_id: OAUTH(:id), 
        client_secret: OAUTH(:secret)
      }.to_params, raw: true, proc_result: block) {|curl|
        if curl.res.code == 200
          body = curl.res.body
          hash = '{['[body[0]] ? body.from_json(symbolize_keys: true) : body.to_params
          user_data(['__app__', nil], [hash.access_token])[0]
        else
          raise OAuthError, curl.res.body
        end
      }
    end
    
    # Если придёт мысль делать враппер клиента по запросу
    #
    # @ action : url or reference to ::API
    # @ args :
    #   token : token or state_params
    #   action_params : smth to append to url
    def api(action, *args, &block)
      if action_data = API(action)
        action, scope = action_data.values_at :path, :scope
        app_token = action_data[:token] == :application
      end
      token, opts = args.get_opts [app_token ? ['__app__'] : ['__default__']]
      opts = opts.symbolize_keys
      action_params = opts.delete(:params) || {}
      redirect_params = opts.extract!(:redirect_protocol)
      
      if token.is Array 
        token[1] ||= scope
        state_params = token
        L.debug state_params
        request_params = [token[0], (token[1] ? {scope: token[1]} : {}).merge(redirect_params)]
        L.debug request_params
        token = validate(*request_params)
        if token.is Hash
          L.debug token
          if block
            return {res: block.(token)}
          else
            return token
          end
        end
      end
      unless token
        raise NoTokenError
      end
      
      L.debug state_params
      action += '?' if !action['?']
      action += action_params.to_params
      L.debug [action_data, action, token]
      opts = {proc_result: block, headers: {'Referer' => nil}, result: CodeIndiffirentPage}.merge(opts)
      # TODO: option to 
      @f.run(URI(:api) % {action: action} + token, opts) {|page|
        if page.hash and page.hash != true and error = page.hash.error
          L.debug state_params
          if error.code.in([190, 100]) and state_params
            user_data state_params, :clear
            L.warn error.message
            if request_params
              {oauth_url: get_oauth_url(*request_params)}
            end
          else
            raise OAuthError, error.message
          end
        else
          page
        end
      }
    end
    
  end
  
end