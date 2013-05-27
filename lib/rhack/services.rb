require 'rhack'
require 'rhack/services/base'

module RHACK
  for name in [:Service, :ServiceError]
    autoload name, 'rhack/services/compatibility'
  end
end