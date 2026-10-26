module CQL
  module ActiveRecord
    # Multi-row INSERT behind `Model.insert_all` and `Model.upsert_all`. Every row is checked before
    # the first statement, and a run of several batches commits or rolls back as a whole.
    struct BulkInsert
      alias Row = Hash(Symbol, DB::Any)

      TIMESTAMP_COLUMNS = {:created_at, :updated_at}

      # ON CONFLICT for `Model.upsert_all`: *target* columns find the existing row, *update* columns take
      # the incoming value (by default every inserted column but the target, the key and `created_at`).
      record Conflict, target : Array(Symbol), update : Array(Symbol)? = nil

      @rows : Array(Row)
      @table_columns : Set(Symbol)
      @generated_ids = false

      # *generate_id* fills a missing or nil *primary_key* (UUID and ULID keys); without it a nil key
      # is dropped so the database assigns one.
      def initialize(@schema : CQL::Schema, @table : Symbol, rows : Array(Row), generate_id : (-> DB::Any)? = nil, @conflict : Conflict? = nil, @primary_key : Symbol = :id)
        @table_columns = @schema.tables[@table].columns.keys.to_set
        @rows = complete(rows, generate_id)
      end

      # Inserts the rows, *batch_size* per statement (by default as many as the dialect's
      # bind-parameter limit allows), and returns the number of rows inserted.
      def call(batch_size : Int32? = nil) : Int64
        per_statement, update = prepare(batch_size)
        return 0_i64 if @rows.empty?
        return statement(@rows, update).commit.rows_affected if @rows.size <= per_statement

        inserted = 0_i64
        @schema.transaction do
          @rows.each_slice(per_statement) { |batch| inserted += statement(batch, update).commit.rows_affected }
        end
        inserted
      end

      # The statement `call` sends for the first batch, checked and built but not run.
      def first_statement(batch_size : Int32? = nil) : CQL::Insert?
        per_statement, update = prepare(batch_size)
        statement(@rows.first(per_statement), update) unless @rows.empty?
      end

      # Checks the arguments and rows; returns the rows per statement and the ON CONFLICT update columns.
      private def prepare(batch_size : Int32?) : {Int32, Array(Symbol)?}
        raise ArgumentError.new("batch_size must be positive, got #{batch_size}") if batch_size && batch_size <= 0
        return {1, nil} if @rows.empty?

        columns = checked_columns
        {rows_per_statement(columns.size, batch_size), @conflict.try { |conflict| checked_update(conflict, columns) }}
      end

      private def statement(batch : Array(Row), update : Array(Symbol)?) : CQL::Insert
        insert = CQL::Insert.new(@schema).into(@table)
        conflict = @conflict
        conflict ? insert.upsert(batch, conflict.target.uniq, update) : insert.values(batch)
      end

      private def checked_update(conflict : Conflict, columns : Set(Symbol)) : Array(Symbol)
        raise ArgumentError.new("on_conflict needs at least one column") if conflict.target.empty?
        require_inserted(conflict.target, columns, "on_conflict")
        if @generated_ids && conflict.target.includes?(@primary_key)
          raise ArgumentError.new("on_conflict: :#{@primary_key} never matches a generated id; give every row its id")
        end
        update = (conflict.update || columns.to_a - conflict.target - [@primary_key, :created_at]).uniq
        require_inserted(update, columns, "update")
        update
      end

      private def require_inserted(names : Array(Symbol), columns : Set(Symbol), option : String) : Nil
        missing = names.reject { |name| columns.includes?(name) }
        return if missing.empty?
        raise ArgumentError.new("#{option} names columns that the rows do not insert into #{@table}: #{missing.join(", ")}")
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
        (row[@primary_key]?.nil? && (row.has_key?(@primary_key) || !generate_id.nil?)) || stamped.any? { |column| row[column]?.nil? }
      end

      private def completed(row : Row, stamped, generate_id : (-> DB::Any)?, now : DB::Any) : Row
        filled = row.dup
        if row[@primary_key]?.nil?
          filled.delete(@primary_key)
          generate_id.try do |generate|
            filled[@primary_key] = generate.call
            @generated_ids = true
          end
        end
        stamped.each { |column| filled[column] = now if row[column]?.nil? }
        filled
      end
    end
  end
end
