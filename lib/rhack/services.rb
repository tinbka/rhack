require 'rhack'
require 'rhack/services/base'
require 'rhack/services/storage'
require 'rhack/services/oauth'

module RHACK
  for name in [:Service, :ServiceError]
    autoload name, 'rhack/services/compatibility'
  end
end