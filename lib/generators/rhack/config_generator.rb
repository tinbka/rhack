module Rhack
  module Generators
    class ConfigGenerator < Rails::Generators::Base
      source_root File.expand_path('../config', __FILE__)
      
      def generate_config
        copy_file "rhack.yml.template", "config/rhack.yml"
      end
    end
  end
end
