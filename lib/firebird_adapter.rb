require 'active_support'

# Require the adapter
ActiveSupport.on_load :active_record do
  ActiveRecord::ConnectionAdapters.register("firebird", "ActiveRecord::ConnectionAdapters::FirebirdAdapter")
end
