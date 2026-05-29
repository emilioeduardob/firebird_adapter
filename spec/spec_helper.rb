require 'bundler/setup'
Bundler.require(:default, :development)

require 'rails'
require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter:  'firebird',
  username: ENV.fetch('FIREBIRD_USERNAME', 'SYSDBA'),
  password: ENV.fetch('FIREBIRD_PASSWORD', 'masterkey'),
  host:     ENV.fetch('FIREBIRD_HOST', 'db'),
  database: ENV.fetch('FIREBIRD_DATABASE', '/firebird/data/example.fdb'),
  encoding: ENV.fetch('FIREBIRD_ENCODING', 'UTF-8'),
)

class SisTest < ActiveRecord::Base
  self.table_name = 'sis_test'
  self.primary_key = 'id_test'
end