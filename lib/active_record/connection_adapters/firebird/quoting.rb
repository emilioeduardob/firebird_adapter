module ActiveRecord::ConnectionAdapters::Firebird::Quoting
  def quoted_date(value)
    super.sub(/(\.\d{6})\z/, $1.to_s.first(5))
  end

  module ClassMethods
    def quote_column_name(name)
      name
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end
end
