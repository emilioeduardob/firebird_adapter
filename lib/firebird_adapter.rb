# Require the adapter
ActiveSupport.on_load :active_record do
  if Rails.version >= "7.2.0"
    ActiveRecord::ConnectionAdapters.register("firebird", "ActiveRecord::ConnectionAdapters::FirebirdAdapter")
  end
end