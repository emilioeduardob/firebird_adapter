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
  # without running it through +cast_result+. For Firebird that raw result is
  # an unconsumed +Fb::Cursor+ when the statement returns rows (e.g. a SELECT),
  # which would leak the cursor and break callers that expect row data. Mirror
  # the historical behavior by consuming and closing the cursor, returning the
  # fetched rows. DML/DDL (which return a row count or nil) pass through.
  def execute(sql, name = nil, allow_retry: false)
    result = super
    return result unless result.is_a?(Fb::Cursor)

    rows = result.fetchall.map do |row|
      row.map { |col| col.is_a?(String) ? col.encode('UTF-8', encoding, invalid: :replace, undef: :replace) : col }
    end
    result.close rescue nil
    rows
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
      notification_payload[:affected_rows] = 0
      notification_payload[:row_count] = 0
    elsif result.is_a?(Numeric)
      notification_payload[:affected_rows] = result
      notification_payload[:row_count] = 0
    else
      notification_payload[:affected_rows] = 0
      notification_payload[:row_count] = 0
    end

    result
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

  def cast_result(raw_result)
    if raw_result.is_a?(Fb::Cursor)
      begin
        fields = raw_result.fields.map(&:name)
        rows = raw_result.fetchall.map do |row|
          row.map do |col|
            if col.is_a?(String)
              col.encode('UTF-8', encoding, invalid: :replace, undef: :replace)
            else
              col
            end
          end
        end
        raw_result.close
        ActiveRecord::Result.new(fields, rows)
      rescue Fb::Error => e
        raw_result.close rescue nil
        if e.message.include?('string right truncation')
          ActiveRecord::Result.new([], [])
        else
          raise e.class, (e.message.encode('UTF-8', encoding) rescue e.message)
        end
      end
    else
      ActiveRecord::Result.new([], [])
    end
  end

  def affected_rows(raw_result)
    if raw_result.is_a?(Numeric)
      raw_result
    else
      0
    end
  end

end
