module Curl
  
  # Run proc in Multi's thread processing callbacks at this moment
  def ITT
    res = nil
    RHACK::Scout('file://').loadGet(__FILE__) {|c| res = yield}
    loop {if res then break res else sleep 0.01 end}
  end
  module_function :ITT
  
end