require 'fb'

require 'active_record/connection_adapters/firebird/connection'
require 'active_record/connection_adapters/firebird/database_limits'
require 'active_record/connection_adapters/firebird/database_statements'
require 'active_record/connection_adapters/firebird/schema_statements'
require 'active_record/connection_adapters/firebird/quoting'

require 'arel/visitors/firebird'

class ActiveRecord::ConnectionAdapters::FirebirdAdapter < ActiveRecord::ConnectionAdapters::AbstractAdapter

  ADAPTER_NAME = "Firebird".freeze
  DEFAULT_ENCODING = "Windows-1252".freeze

  include ActiveRecord::ConnectionAdapters::Firebird::DatabaseLimits
  include ActiveRecord::ConnectionAdapters::Firebird::DatabaseStatements
  include ActiveRecord::ConnectionAdapters::Firebird::SchemaStatements
  include ActiveRecord::ConnectionAdapters::Firebird::Quoting

  def initialize(config_or_connection = nil)
    if config_or_connection.is_a?(Hash)
      # Rails 8+ preferred path: config hash only, connection is deferred
      # to reconnect! via verify!.
      super(config_or_connection)
    else
      # Legacy path: accept a pre-built Fb connection object.
      @connection = config_or_connection
      super(config_or_connection)
    end
  end

  def arel_visitor
    @arel_visitor ||= Arel::Visitors::Firebird.new(self)
  end

  def prefetch_primary_key?(table_name = nil)
    true
  end

  def active?
    return false unless @connection&.open?

    @connection.query("SELECT 1 FROM RDB$DATABASE")
    true
  rescue
    false
  end

  # Rails 8.1 calls +reconnect!+ with the +restore_transactions+ keyword.
  # We accept it (defaulting to false) so the adapter stays compatible with
  # both Rails 8.0 and 8.1. A freshly opened connection has no live
  # transaction to restore, so the keyword is intentionally a no-op here.
  def reconnect!(restore_transactions: false)
    disconnect!
    @connection = ::Fb::Database.connect(
      database: @config[:database],
      username: @config[:username],
      password: @config[:password],
      charset: @config[:encoding] || self.class::DEFAULT_ENCODING,
      downcase_names: true
    )
    @raw_connection = @connection
  end

  def disconnect!
    super
    @connection&.close
    @raw_connection = nil
  end

  def reset!
    reconnect!
  end

  def primary_keys(table_name)
    raise ArgumentError unless table_name.present?

    names = query_values(<<~SQL, "SCHEMA")
      SELECT
        s.rdb$field_name
      FROM
        rdb$indices i
        JOIN rdb$index_segments s ON i.rdb$index_name = s.rdb$index_name
        LEFT JOIN rdb$relation_constraints c ON i.rdb$index_name = c.rdb$index_name
      WHERE
        i.rdb$relation_name = '#{table_name.upcase}'
        AND c.rdb$constraint_type = 'PRIMARY KEY';
    SQL

    names.map(&:strip).map(&:downcase)
  end

  def encoding
    @connection&.encoding || @config[:encoding] || self.class::DEFAULT_ENCODING
  end

  # The +log+ signature gained keyword arguments over the Rails 8.x series
  # (+async:+ in 8.0, +allow_retry:+ in 8.1). We capture them with +**kwargs+
  # and forward them verbatim so the override works on every 8.x release.
  def log(sql, name = "SQL", binds = [], type_casted_binds = [], **kwargs, &block) # :doc:
    sql = sql.encode('UTF-8', encoding) if sql.encoding.to_s == encoding
    super(sql, name, binds, type_casted_binds, **kwargs, &block)
  end

  def supports_foreign_keys?
    true
  end

protected

  def translate_exception(e, message)
    case e.message
    when /violation of FOREIGN KEY constraint/
      ActiveRecord::InvalidForeignKey.new(message)
    when /violation of PRIMARY or UNIQUE KEY constraint/, /attempt to store duplicate value/
      ActiveRecord::RecordNotUnique.new(message)
    when /This operation is not defined for system tables/
      ActiveRecord::ActiveRecordError.new(message)
    else
      super
    end
  end

end
