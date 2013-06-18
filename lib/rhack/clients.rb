require 'rhack'
require 'rhack/clients/base'
require 'rhack/clients/storage'
require 'rhack/clients/oauth'

module RHACK
  for name in [:Service, :ServiceError]
    autoload name, 'rhack/clients/compatibility'
  end
end