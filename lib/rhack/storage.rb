# encoding: utf-8
module RHACK
  
  class Storage
    __init__
    include Redis::Objects
    class TypeError < ::TypeError; end
    
    def initialize(type, namespace)
      @namespace = namespace
      @type = type
    end
    
    def inspect
      "<#Storage #{@namespace}: #{@type}>"
    end
    alias :to_s :inspect
    
    # set пригодится как для массового переноса или обновления всего неймспейса (реже),
    # так и для &-проверки на стороне руби, какие ключи нужных данных вообще стоит дёргать (чаще)
    def keys
      Set redis.smembers(@namespace)
    end
      
    # TODO:
    # @ opts should apply to redis.command, e.g. "use zadd instead of sadd"
    def __store(key, data, opts={})
      item_key = "#{@namespace}:#{key}"
      case @type
      when :hash
        redis.hmset item_key, *data.to_a
      when :set
        redis.sadd item_key, data.to_a
      when :zset
        redis.zadd item_key, data.to_a
      end
      data
    end
    
    def store(key, data)
      redis.sadd(@namespace, key)
      __store(key, data)
    end
    alias :[]= :store
    
    def storenx(key, data)
      if redis.sadd(@namespace, key)
        __store(key, data)
        true
      else false
      end
    end
    
    def fetch(key)
      item_key = "#{@namespace}:#{key}"
      case @type
      when :hash
        redis.hgetall item_key
      when :set
        redis.smembers item_key
      when :zset
        # it will become better if I'll find use case for it
        redis.zrange item_key, 0, -1
      end
    end
    alias :[] :fetch
    
    def fetchex(key, overwrite=nil)
      exists = overwrite.nil? ? exists?(key) : !overwrite
      if exists
        fetch(key)
      else
        if res = yield
          store key, res
          res
        end
      end
    end
    
    def exists?(key)
      redis.type("#{@namespace}:#{key}") != 'none'
    end
    alias :ex :exists?
    
    def all
      redis.smembers(@namespace).map_hash {|key|
        [key, redis.fetch(key)]
      }
    end
    
    def del(key)
      if redis.srem(@namespace, key)
        redis.del "#{@namespace}:#{key}"
      end
    end
    
    def wipe!
      redis.smembers(@namespace).each {|key|
        redis.del "#{@namespace}:#{key}"
      }
      redis.del @namespace
    end
    
  end
  
end