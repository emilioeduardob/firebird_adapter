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
      config = config_or_connection.symbolize_keys.dup
      config.reverse_merge!(downcase_names: true, port: 3050, encoding: self.class::DEFAULT_ENCODING)

      # Transform the database path for Firebird connection string format,
      # but only if it hasn't already been transformed (e.g. by the legacy
      # firebird_connection factory on Rails 8.0).
      if config[:host] && !config[:database].to_s.start_with?("#{config[:host]}/")
        config[:database] = "#{config[:host]}/#{config[:port]}:#{config[:database]}"
      elsif !config[:host]
        config[:database] = File.expand_path(config[:database], Rails.root)
      end

      super(config)
    else
      # Legacy path: accept a pre-built Fb connection object.
      super(config_or_connection)
      @connection = config_or_connection
      @raw_connection = config_or_connection
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

  def disconnect!
    super
    @connection&.close rescue nil
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
    @config[:encoding] || self.class::DEFAULT_ENCODING
  end

  def lookup_cast_type(sql_type)
    if sql_type.to_s.downcase.include?('blob sub_type text')
      ActiveRecord::Type::Text.new
    else
      super
    end
  end

  def log(sql, name = "SQL", binds = [], type_casted_binds = [], async: false, allow_retry: false, &block) # :doc:
    sql = sql.encode('UTF-8', encoding) if sql.encoding.to_s == encoding
    super
  end

  def supports_foreign_keys?
    true
  end

  READ_QUERY = /^\s*(SELECT|WITH\s.+\sSELECT)\b/i

  def write_query?(sql)
    !READ_QUERY.match?(sql)
  rescue ArgumentError
    !READ_QUERY.match?(sql.b)
  end

protected

  def translate_exception(e, message:, sql:, binds:)
    case e.message
    when /violation of FOREIGN KEY constraint/
      ActiveRecord::InvalidForeignKey.new(message, sql: sql, binds: binds, connection_pool: @pool)
    when /violation of PRIMARY or UNIQUE KEY constraint/, /attempt to store duplicate value/
      ActiveRecord::RecordNotUnique.new(message, sql: sql, binds: binds, connection_pool: @pool)
    when /This operation is not defined for system tables/
      ActiveRecord::ActiveRecordError.new(message)
    else
      super
    end
  end

private

  def connect
    @connection = ::Fb::Database.connect(
      database: @config[:database],
      username: @config[:username],
      password: @config[:password],
      charset: @config[:encoding] || self.class::DEFAULT_ENCODING,
      downcase_names: true
    )
    @raw_connection = @connection
  end

  def reconnect
    @connection&.close rescue nil
    @connection = nil
    @raw_connection = nil
    connect
  end

end
