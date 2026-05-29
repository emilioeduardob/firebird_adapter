class ActiveRecord::InternalMetadata
  if superclass == ActiveRecord::Base
    # Rails 8.0 and earlier: InternalMetadata is an ActiveRecord::Base subclass
    # with class methods.
    class << self
      def adapter_name
        connection.adapter_name.downcase.to_sym
      end

      def value_name
        adapter_name == :firebird ? :value_ : :value
      end

      def []=(key, value)
        find_or_initialize_by(key: key).update!(value_name => value)
      end

      def [](key)
        where(key: key).pluck(value_name).first
      end

      def create_table
        unless table_exists?
          key_options = connection.internal_string_options_for_primary_key

          connection.create_table(table_name, id: false) do |t|
            t.string :key, key_options
            t.string value_name
            t.timestamps
          end
        end
      end
    end
  else
    # Rails 8.1+: InternalMetadata is a plain class instantiated per pool.
    def value_key
      if @pool.with_connection { |c| c.adapter_name.downcase.to_sym == :firebird }
        "value_"
      else
        super
      end
    end

    def create_table
      return unless enabled?

      @pool.with_connection do |connection|
        unless connection.table_exists?(table_name)
          connection.create_table(table_name, id: false) do |t|
            t.string :key, **connection.internal_string_options_for_primary_key
            t.string(connection.adapter_name.downcase.to_sym == :firebird ? :value_ : :value)
            t.timestamps
          end
        end
      end
    end
  end
end
