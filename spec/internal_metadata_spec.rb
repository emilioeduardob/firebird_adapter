require 'spec_helper'

describe 'internal metadata' do

  before(:all) do
    ActiveRecord::Base.connection
  end

  after(:all) do
    ActiveRecord::Base.connection.execute('DROP TABLE ar_internal_metadata') rescue nil
  end

  it '#create_table' do
    if ActiveRecord::InternalMetadata.superclass == ActiveRecord::Base
      # Rails 8.0 and earlier
      expect { ActiveRecord::InternalMetadata.create_table }.not_to raise_error
    else
      # Rails 8.1+: create_table is an instance method on the pool's InternalMetadata
      expect { ActiveRecord::Base.connection_pool.internal_metadata.create_table }.not_to raise_error
    end
  end

end
