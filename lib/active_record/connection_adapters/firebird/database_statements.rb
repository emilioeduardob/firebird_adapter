module ActiveRecord::ConnectionAdapters::Firebird::DatabaseStatements

  def native_database_types
    {
      primary_key: 'integer not null primary key',
      string:      { name: 'varchar', limit: 255 },
      text:        { name: 'blob sub_type text' },
      integer:     { name: 'integer' },
      float:       { name: 'float' },
      decimal:     { name: 'decimal' },
      datetime:    { name: 'timestamp' },
      timestamp:   { name: 'timestamp' },
      date:        { name: 'date' },
      binary:      { name: 'blob' },
      boolean:     { name: 'smallint' }
    }
  end

  # Rails 8.1's base +execute+ returns the raw result of +perform_query+
  # without running it through +cast_result+. For Firebird, a row-returning
  # statement (e.g. a SELECT) is materialized by +perform_query+ into an
  # +ActiveRecord::Result+. Mirror the historical behavior of +execute+ by
  # returning the plain array of rows in that case; DML/DDL results (a row
  # count or nil) pass through unchanged.
  def execute(sql, name = nil, allow_retry: false)
    result = super
    result.is_a?(ActiveRecord::Result) ? result.rows : result
  end

  def begin_db_transaction
    verify!
    log("begin transaction", nil) { @connection.transaction('READ COMMITTED') }
  end

  def commit_db_transaction
    verify!
    log("commit transaction", nil) { @connection.commit }
  end

  def exec_rollback_db_transaction
    verify!
    log("rollback transaction", nil) { @connection.rollback }
  end

  def create_table(table_name, **options)
    super

    if options[:sequence] != false && options[:id] != false
      sequence_name = options[:sequence] || default_sequence_name(table_name)
      create_sequence(sequence_name)
    end
  end

  def drop_table(table_name, options = {})
    if options[:sequence] != false
      sequence_name = options[:sequence] || default_sequence_name(table_name)
      drop_sequence(sequence_name) if sequence_exists?(sequence_name)
    end

    super
  end

  def create_sequence(sequence_name)
    execute("CREATE SEQUENCE #{sequence_name}") rescue nil
  end

  def drop_sequence(sequence_name)
    execute("DROP SEQUENCE #{sequence_name}") rescue nil
  end

  def sequence_exists?(sequence_name)
    verify!
    @connection.generator_names.include?(sequence_name)
  end

  def default_sequence_name(table_name, _column = nil)
    "#{table_name}_g01"
  end

  def next_sequence_value(sequence_name)
    verify!
    @connection.query("SELECT NEXT VALUE FOR #{sequence_name} FROM RDB$DATABASE")[0][0]
  end

  def insert(arel, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [], returning: nil)
    pk = nil if id_value
    result = super
    Array((result&.is_a?(Array) ? result.first : result) || id_value)
  end

  private

  def perform_query(raw_connection, sql, binds, type_casted_binds, prepare:, notification_payload:, batch:)
    sql = sql.encode(encoding, 'UTF-8')

    type_casted_binds = type_casted_binds.map do |value|
      value = value.to_s unless value.is_a?(String)
      value.encode(encoding) rescue value
    end

    result = if type_casted_binds.empty?
      raw_connection.execute(sql)
    else
      raw_connection.execute(sql, *type_casted_binds)
    end

    if result.is_a?(Fb::Cursor)
      # Materialize the cursor here, rather than deferring to +cast_result+, so
      # the row count is known while the SQL notification payload is still open
      # (instrumentation/logging reads it before +cast_result+ runs).
      fields = result.fields.map(&:name)
      rows = result.fetchall.map do |row|
        row.map do |col|
          col.is_a?(String) ? col.encode('UTF-8', encoding, invalid: :replace, undef: :replace) : col
        end
      end
      result.close
      notification_payload[:affected_rows] = 0
      notification_payload[:row_count] = rows.size

      # No +column_types+ are supplied: unlike libpq (PostgreSQL), the +fb+
      # driver already returns native Ruby objects (Integer, Float, BigDecimal,
      # Date, Time, String), so there is nothing to cast. Passing a type map
      # here would only risk double-casting and could corrupt the schema
      # introspection queries that flow through +query+/+query_values+.
      ActiveRecord::Result.new(fields, rows)
    elsif result.is_a?(Numeric)
      notification_payload[:affected_rows] = result
      notification_payload[:row_count] = 0
      result
    else
      notification_payload[:affected_rows] = 0
      notification_payload[:row_count] = 0
      result
    end
  rescue StandardError => e
    if result.is_a?(Fb::Cursor)
      result.close rescue nil
    end
    # Firebird raises "string right truncation" when a bind value is wider than
    # the column it is compared against. For a SELECT no row could ever match
    # such a value, so returning an empty result is semantically correct (and
    # avoids crashing on otherwise valid lookups). Write statements still raise.
    if e.message.include?('string right truncation') && sql.to_s.strip.downcase.start_with?('select')
      return ActiveRecord::Result.new([], [])
    end
    new_message = e.message.encode('UTF-8', encoding) rescue e.message
    raise e.class, new_message, e.backtrace
  end

  # +perform_query+ already materializes row-returning statements into an
  # +ActiveRecord::Result+ (so the row count is available for instrumentation),
  # so here we only need to pass it through. Non-row results (DML row counts,
  # nil) become an empty result.
  def cast_result(raw_result)
    raw_result.is_a?(ActiveRecord::Result) ? raw_result : ActiveRecord::Result.new([], [])
  end

  def affected_rows(raw_result)
    if raw_result.is_a?(Numeric)
      raw_result
    else
      0
    end
  end

end
