module CQL
  module ActiveRecord
    # Multi-row INSERT behind `Model.insert_all`. Every row is checked before the first statement,
    # and a run of several batches commits or rolls back as a whole.
    struct BulkInsert
      alias Row = Hash(Symbol, DB::Any)

      TIMESTAMP_COLUMNS = {:created_at, :updated_at}

      @rows : Array(Row)
      @table_columns : Set(Symbol)

      # *generate_id* fills a missing or nil `:id` (UUID and ULID keys); without it a nil `:id` is
      # dropped so the database assigns one.
      def initialize(@schema : CQL::Schema, @table : Symbol, rows : Array(Row), generate_id : (-> DB::Any)? = nil)
        @table_columns = @schema.tables[@table].columns.keys.to_set
        @rows = complete(rows, generate_id)
      end

      # Inserts the rows, *batch_size* per statement (by default as many as the dialect's
      # bind-parameter limit allows), and returns the number of rows inserted.
      def call(batch_size : Int32? = nil) : Int64
        raise ArgumentError.new("batch_size must be positive, got #{batch_size}") if batch_size && batch_size <= 0
        return 0_i64 if @rows.empty?

        per_statement = rows_per_statement(checked_columns.size, batch_size)
        return insert(@rows) if @rows.size <= per_statement

        inserted = 0_i64
        @schema.transaction { @rows.each_slice(per_statement) { |batch| inserted += insert(batch) } }
        inserted
      end

      private def insert(batch : Array(Row)) : Int64
        CQL::Insert.new(@schema).into(@table).values(batch).commit.rows_affected
      end

      private def rows_per_statement(column_count : Int32, batch_size : Int32?) : Int32
        limit = @schema.adapter.dialect.max_bind_params
        fitting = {limit // column_count, 1}.max
        return fitting unless batch_size
        return batch_size if batch_size <= fitting
        raise ArgumentError.new("batch_size #{batch_size} binds more than #{limit} values with #{column_count} columns")
      end

      private def checked_columns : Set(Symbol)
        columns = @rows.first.keys.to_set
        raise ArgumentError.new("insert_all rows need at least one column") if columns.empty?
        unknown = columns - @table_columns
        raise ArgumentError.new("Unknown columns for #{@table}: #{unknown.join(", ")}") unless unknown.empty?
        @rows.each do |row|
          next if row.size == columns.size && row.each_key.all? { |key| columns.includes?(key) }
          raise ArgumentError.new("insert_all rows must all have the same keys (expected #{columns.join(", ")})")
        end
        columns
      end

      # Adds what a row leaves out or sets to nil: a generated id and the timestamps.
      private def complete(rows : Array(Row), generate_id : (-> DB::Any)?) : Array(Row)
        stamped = TIMESTAMP_COLUMNS.select { |column| @table_columns.includes?(column) }
        now = Time.utc.as(DB::Any)
        rows.map { |row| incomplete?(row, stamped, generate_id) ? completed(row, stamped, generate_id, now) : row }
      end

      private def incomplete?(row : Row, stamped, generate_id : (-> DB::Any)?) : Bool
        (row[:id]?.nil? && (row.has_key?(:id) || !generate_id.nil?)) || stamped.any? { |column| row[column]?.nil? }
      end

      private def completed(row : Row, stamped, generate_id : (-> DB::Any)?, now : DB::Any) : Row
        filled = row.dup
        if row[:id]?.nil?
          filled.delete(:id)
          generate_id.try { |generate| filled[:id] = generate.call }
        end
        stamped.each { |column| filled[column] = now if row[column]?.nil? }
        filled
      end
    end
  end
end
