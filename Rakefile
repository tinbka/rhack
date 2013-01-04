require 'rake'
begin
  require 'rmtools_dev'
  require 'rmtools/install'
rescue LoadError
  puts "cannot load the RMTools gem. Distribution is disabled. Please 'sudo gem install rmtools' first"
  exit
end

compile_manifest
RHACK_VERSION = '0.4.0'
begin
    require 'hoe'
    config = Hoe.spec "rhack" do |h|
        h.developer("Sergey Baev", "tinbka@gmail.com")

        h.description = 'Webscraping library based on curb gem extension and libxml-ruby (and optionally Johnson and ActiveRecord)'
       # h.summary = h.description
        h.urls = ['https://github.com/tinbka/rhack']
       
        h.extra_deps << ['rmtools','>= 1.2.13']
        h.extra_deps << ['rake','>= 0.8.7']
        #h.extra_deps << ['johnson','>= 2.0.0.pre3']
        h.extra_deps << ['libxml-ruby','>= 1.1.3']
    end
    config.spec.extensions << 'ext/curb/extconf.rb'
rescue LoadError => e
    STDERR.puts "cannot load the Hoe gem. Distribution is disabled"
    raise e
rescue Exception => e
    STDERR.puts "cannot load the Hoe gem, or Hoe fails. Distribution is disabled"
    STDERR.puts "error message is: #{e.message}"
    raise e
end