# encoding: utf-8

module RHACK 
  class Client
    class_attribute :storage
    self.storage = {}
    attr_reader :storage
    
    def self.store(type, name, opts={})
      storage[name] = RHACK::Storage(type, (opts[:prefix] || self.name.sub('RHACK::', '').underscore)+':'+name)
    end
  end
end