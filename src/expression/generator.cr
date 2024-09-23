module Expression
  class Generator
    include Visitor

    @dialect : Dialect
    getter params : Array(DB::Any) = [] of DB::Any
    getter query : String = ""

    def initialize(@adapter : Cql::Adapter = Cql::Adapter::Sqlite)
      @dialect, @placeholder = case @adapter
                               when Cql::Adapter::Sqlite
                                 {SqliteDialect.new, "?"}
                               when Cql::Adapter::MySql
                                 {MysqlDialect.new, "?"}
                               else
                                 {PostgresDialect.new, "$"}
                               end
    end

    def reset
      @params.clear
      @query = ""
    end

    private def placeholder : String
      return @placeholder unless @adapter == Cql::Adapter::Postgres
      "#{@placeholder}#{(@params.size)}"
    end

    # Template Method for common visit methods
    def visit(node : Query) : String
      @params.clear
      @query = String.build do |string|
        string << "SELECT "
        string << "DISTINCT " if node.distinct?
        string << node.columns.map(&.accept(self)).join(", ")
        string << ", " if !node.aggr_columns.empty? && !node.columns.empty?
        string << node.aggr_columns.map(&.accept(self)).join(", ")
        string << node.from.accept(self)
        node.joins.each { |join| string << join.accept(self) }
        string << node.where.try &.accept(self) if node.where
        string << node.group_by.try &.accept(self) if node.group_by
        string << node.having.try &.accept(self) if node.having
        string << node.order_by.not_nil!.accept(self) if node.order_by
        string << node.limit.try &.accept(self) if node.limit
      end
    end

    def visit(node : Join) : String
      String.build do |string|
        string << " #{node.join_type.to_s.upcase} JOIN "
        string << node.table.accept(self)
        string << " ON "
        string << node.condition.accept(self)
      end
    end

    def visit(node : Insert) : String
      columns = if node.query.nil?
                  node.columns
                else
                  node.query.not_nil!.columns
                end

      @query = String.build do |string|
        string << "INSERT INTO "
        string << node.table.accept(self)
        string << " ("
        columns.each_with_index do |col, i|
          string << col.column.name
          string << ", " if i < columns.size - 1
        end
        string << ")"

        if q = node.query
          string << " " << q.accept(self)
        else
          string << " VALUES "
          node.values.each_with_index do |row, i|
            string << "("
            row.each_with_index do |val, j|
              @params << val
              string << "#{placeholder}"
              string << ", " if j < row.size - 1
            end
            if i < node.values.size - 1
              string << "), "
            else
              string << ")"
            end
          end
          if !node.back.empty?
            string << " RETURNING ("
            node.back.each_with_index do |column, i|
              string << column.accept(self)
              string << ", " if i < node.back.size - 1
            end
            string << ")"
          end
        end
      end
    end

    def visit(node : Delete) : String
      @query = String.build do |string|
        string << "DELETE FROM "
        string << node.table.accept(self)
        if using = node.using
          string << " USING " << using.accept(self)
        end
        string << node.where.not_nil!.accept(self) if node.where
        if !node.back.empty?
          string << " RETURNING ("
          node.back.each_with_index do |column, i|
            string << column.accept(self)
            string << ", " if i < node.back.size - 1
          end
          string << ")"
        end
      end
    end

    def visit(node : Where) : String
      String.build do |string|
        string << " WHERE ("
        string << node.condition.accept(self)
        string << ")"
      end
    end

    def visit(node : Column) : String
      String.build do |string|
        unless node.column.name == :*
          string << node.column.table.not_nil!.table_name
          string << "."
        end
        string << node.column.name
      end
    end

    def visit(node : And) : String
      String.build do |string|
        string << node.left.accept(self)
        string << " AND "
        string << node.right.accept(self)
      end
    end

    def visit(node : Or) : String
      String.build do |string|
        string << node.left.accept(self)
        string << " OR "
        string << node.right.accept(self)
      end
    end

    def visit(node : Not) : String
      String.build do |string|
        string << "NOT "
        string << node.condition.accept(self)
      end
    end

    def visit(node : Compare) : String
      @params << node.right
      String.build do |string|
        string << node.left.accept(self)
        string << " "
        string << node.operator
        string << " "
        string << placeholder
      end
    end

    def visit(node : CompareCondition) : String
      String.build do |string|
        if node.left.is_a?(Column) || node.left.is_a?(Condition)
          string << node.left.as(Column | Condition).accept(self)
        else
          @params << node.left.as(DB::Any)
          string << placeholder
        end
        string << " "
        string << node.operator
        string << " "
        if node.right.is_a?(Column) || node.right.is_a?(Condition)
          string << node.right.as(Column | Condition).accept(self)
        else
          @params << node.right.as(DB::Any)
          string << placeholder
        end
      end
    end

    def visit(node : Between) : String
      @params << node.low
      @params << node.high
      String.build do |string|
        string << node.column.accept(self)
        string << " BETWEEN "
        string << placeholder
        string << " AND "
        string << placeholder
      end
    end

    def visit(node : Like) : String
      @params << node.value
      "#{node.column.accept(self)} LIKE #{placeholder}"
    end

    def visit(node : NotLike) : String
      @params << node.value
      "#{node.column.accept(self)} NOT LIKE #{placeholder}"
    end

    def visit(node : InCondition) : String
      String.build do |string|
        string << node.column.accept(self)
        string << " IN ("
        node.values.each_with_index do |value, i|
          @params << value
          string << placeholder
          string << ", " if i < node.values.size - 1
        end
        string << ")"
      end
    end

    def visit(node : OrderBy) : String
      return "" if node.orders.empty?
      String.build do |string|
        string << " ORDER BY "
        node.orders.each_with_index do |(column, direction), i|
          string << column.accept(self)
          string << " "
          string << direction.to_s.upcase
          string << ", " if i < node.orders.size - 1
        end
      end
    end

    def visit(node : GroupBy) : String
      return "" if node.columns.empty?

      String.build do |string|
        string << " GROUP BY "
        node.columns.each_with_index do |column, i|
          string << column.accept(self)
          string << ", " if i < node.columns.size - 1
        end
      end
    end

    def visit(node : InSelect) : String
      String.build do |string|
        string << node.column.accept(self)
        string << " IN ("
        string << node.query.accept(self)
        string << ")"
      end
    end

    def visit(node : Exists) : String
      String.build do |string|
        string << "EXISTS ("
        string << node.sub_query.accept(self)
        string << ")"
      end
    end

    def visit(node : Having) : String
      String.build do |string|
        string << " HAVING "
        string << node.condition.accept(self)
      end
    end

    def visit(node : Limit) : String
      String.build do |string|
        @params << node.limit
        string << " LIMIT #{placeholder}"
        if node.offset
          @params << node.offset
          string << " OFFSET #{placeholder}"
        end
      end
    end

    def visit(node : Top) : String
      String.build do |string|
        string << "TOP "
        string << node.count.to_s
      end
    end

    def visit(node : From) : String
      String.build do |string|
        string << " FROM "
        node.tables.each_with_index do |table, i|
          string << table.table_name
          string << " AS " << table.as_name if table.as_name
          string << ", " if i < node.tables.size - 1
        end
      end
    end

    def visit(node : Table) : String
      node.table.table_name.to_s
    end

    def visit(node : Null) : String
      String.build do |string|
        string << "NULL"
        if column = node.column
          string << column.accept(self)
        end
      end
    end

    def visit(node : Is) : String
      @params << node.value
      "#{node.column.accept(self)} IS #{placeholder}"
    end

    def visit(node : IsNull) : String
      "#{node.column.accept(self)} IS NULL"
    end

    def visit(node : IsNot) : String
      @params << node.value
      "#{node.column.accept(self)} IS NOT #{placeholder}"
    end

    def visit(node : IsNotNull) : String
      "#{node.column.accept(self)} IS NOT NULL"
    end

    def visit(node : EmptyNode) : String
      ""
    end

    def visit(node : Count) : String
      "COUNT(#{node.column.accept(self)})"
    end

    def visit(node : Max) : String
      "MAX(#{node.column.accept(self)})"
    end

    def visit(node : Min) : String
      "MIN(#{node.column.accept(self)})"
    end

    def visit(node : Avg) : String
      "AVG(#{node.column.accept(self)})"
    end

    def visit(node : Sum) : String
      "SUM(#{node.column.accept(self)})"
    end

    def visit(node : Setter) : String
      @params << node.value
      "#{node.column.column.name} = #{placeholder}"
    end

    def visit(node : Update) : String
      @query = String.build do |string|
        string << "UPDATE "
        string << node.table.accept(self)
        string << " SET "
        node.setters.each_with_index do |setter, i|
          string << setter.accept(self)
          string << ", " if i < node.setters.size - 1
        end
        if where = node.where
          string << where.accept(self)
        end
        if !node.back.empty?
          string << " RETURNING "
          node.back.each_with_index do |column, i|
            string << column.accept(self)
            string << ", " if i < node.back.size - 1
          end
        end
      end
    end

    def visit(node : CreateIndex) : String
      @query = String.build do |string|
        string << "CREATE "
        string << "UNIQUE " if node.index.unique?
        string << "INDEX "
        string << node.index.index_name
        string << " ON "
        string << node.index.table.table_name
        string << " ("
        string << node.index.columns.map(&.to_s).join(", ")
        string << ")"
      end
    end

    def visit(node : CreateTable) : String
      @query = String.build do |string|
        string << "CREATE TABLE IF NOT EXISTS "
        string << node.table.table_name
        string << " ("

        node.table.columns.each_with_index do |(name, column), i|
          if column.is_a?(Cql::PrimaryKey)
            string << @dialect.auto_increment_primary_key(column, @adapter.sql_type(column.type))
          else
            string << column.name
            string << " " << @adapter.sql_type(column.type)
            if [:created_at, :updated_at].includes?(column.name)
              string << " DEFAULT " << column.default
            elsif column.default
              string << " DEFAULT " << column.default
            end
            string << " NOT NULL" unless column.null?
            string << " UNIQUE" if column.unique?
          end
          string << ", " if i < node.table.columns.size - 1
        end
        string << ")"
      end
    end

    def visit(node : DropTable) : String
      @query = "DROP TABLE IF EXISTS #{node.table.table_name}"
    end

    def visit(node : TruncateTable) : String
      @query = "TRUNCATE TABLE #{node.table.table_name}"
    end

    # Add support for AlterTable
    def visit(node : AlterTable) : String
      @query = "ALTER TABLE #{node.table.table_name} #{node.action.accept(self)}"
    end

    def visit(node : AddColumn) : String
      String.build do |string|
        string << "ADD COLUMN "
        string << node.column.name
        string << " " << @adapter.sql_type(node.column.type)
        string << " PRIMARY KEY" if node.column.is_a?(Cql::PrimaryKey)
        string << " NOT NULL" unless node.column.null?
        string << " UNIQUE" if node.column.unique?
      end
    end

    def visit(node : DropColumn) : String
      "DROP COLUMN #{node.column_name}"
    end

    def visit(node : DropIndex) : String
      @dialect.drop_index(node.index.index_name, node.index.table.table_name.to_s)
    end

    def visit(node : RenameColumn) : String
      @dialect.rename_column(
        node.table_name,
        node.old_name,
        node.new_name,
        @adapter.sql_type(node.column.type)
      )
    end

    def visit(node : RenameTable) : String
      @dialect.rename_table(node.table.table_name.to_s, node.new_name)
    end

    def visit(node : ChangeColumn) : String
      @dialect.modify_column(
        node.table_name,
        node.column.name.to_s,
        @adapter.sql_type(node.column.type)
      )
    end

    def visit(node : AddForeignKey) : String
      if @adapter == Cql::Adapter::Sqlite
        message = <<-MSG
              SQLite does not support adding foreign keys to an \n
              existing table directly via the ALTER TABLE statement.\n
              You need to recreate the table with the foreign key constraint.\n
              Here is an example workflow:

                1. Create the new table with the foreign key.
                2. Copy data from the old table to the new table.
                3. Drop the old table.
                4. Rename the new table to the old table name.
            MSG
        raise DB::Error.new message
      end

      String.build do |string|
        string << "ADD CONSTRAINT "
        string << node.fk.name
        string << " FOREIGN KEY ("
        string << node.fk.columns.map(&.to_s).join(", ")
        string << ") REFERENCES "
        string << node.fk.table
        string << " ("
        string << node.fk.references.map(&.to_s).join(", ")
        string << ") ON DELETE " << node.fk.on_delete
        string << " ON UPDATE " << node.fk.on_update
      end
    end

    def visit(node : DropForeignKey) : String
      @dialect.drop_foreign_key(node.table, node.fk)
    end
  end
end
