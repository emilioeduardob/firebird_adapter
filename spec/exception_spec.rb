require 'spec_helper'

describe 'exception' do

  before(:all) do
    @initial_encoding ||= ActiveRecord::Base.connection_db_config.configuration_hash[:encoding] || ActiveRecord::ConnectionAdapters::FirebirdAdapter::DEFAULT_ENCODING
    begin
      ActiveRecord::Base.establish_connection(ActiveRecord::Base.connection_db_config.configuration_hash.merge(encoding: 'Windows-1252'))
      ActiveRecord::Base.connection.execute("SELECT 1 FROM RDB$DATABASE")
      @windows_1252_available = true
    rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid, Fb::Error
      @windows_1252_available = false
      ActiveRecord::Base.establish_connection(ActiveRecord::Base.connection_db_config.configuration_hash.merge(encoding: @initial_encoding))
    end
  end

  after(:all) do
    ActiveRecord::Base.establish_connection(ActiveRecord::Base.connection_db_config.configuration_hash.merge(encoding: @initial_encoding))
  end

  it 'execute block with exception' do
    skip 'Windows-1252 charset not available in this Firebird installation' unless @windows_1252_available

    expect do
      ActiveRecord::Base.connection.exec_query <<-SQL
        EXECUTE BLOCK
        AS
        BEGIN
          EXCEPTION ERROR('A1áéíóúàçã9z');
        END
      SQL
    end.to raise_error(Exception, /A1áéíóúàçã9z/)
  end

end
