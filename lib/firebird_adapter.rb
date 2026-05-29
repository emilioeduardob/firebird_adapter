require 'active_support'

# Require the adapter
ActiveSupport.on_load :active_record do
  ActiveRecord::ConnectionAdapters.register("firebird", "ActiveRecord::ConnectionAdapters::FirebirdAdapter")
  require 'active_record/internal_metadata_extensions'
end
