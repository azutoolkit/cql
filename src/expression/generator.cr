module Expression
  class Generator
    include Visitor

    @dialect : Dialect

    def initialize(@adapter : Sql::Adapter = Sql::Adapter::Sqlite)
      @dialect = case @adapter
                 when Sql::Adapter::Sqlite
                   SqliteDialect.new
                 when Sql::Adapter::Mysql
                   MysqlDialect.new
                 else
                   PostgresDialect.new
                 end
    end

    # Template Method for common visit methods
    def visit(node : Query) : String
      String::Builder.build do |sb|
        sb << "SELECT "
        sb << "DISTINCT " if node.distinct?
        sb << node.aggr_columns.map { |c| c.accept(self) }.join(", ")
        sb << ", " if node.aggr_columns.any? && node.columns.any?
        sb << node.columns.map { |c| c.accept(self) }.join(", ")
        sb << node.from.accept(self)
        node.joins.each { |join| sb << join.accept(self) }
        sb << node.where.try &.accept(self) if node.where
        sb << node.group_by.try &.accept(self) if node.group_by
        sb << node.having.try &.accept(self) if node.having
        sb << node.order_by.not_nil!.accept(self) if node.order_by
        sb << node.limit.try &.accept(self) if node.limit
      end
    end

    def visit(node : Join) : String
      String::Builder.build do |sb|
        sb << " #{node.join_type.to_s.upcase} JOIN "
        sb << node.table.accept(self)
        sb << " ON "
        sb << node.condition.accept(self)
      end
    end

    def visit(node : Insert) : String
      columns = if node.query.nil?
                  node.columns
                else
                  node.query.not_nil!.columns
                end

      String::Builder.build do |sb|
        sb << "INSERT INTO "
        sb << node.table.accept(self)
        sb << " ("
        columns.each_with_index do |col, i|
          sb << col.column.name
          sb << ", " if i < columns.size - 1
        end
        sb << ")"

        if q = node.query
          sb << " " << q.accept(self)
        else
          sb << " VALUES "
          node.values.each_with_index do |row, i|
            sb << "("
            row.each_with_index do |val, j|
              sb << val.to_s
              sb << ", " if j < row.size - 1
            end
            if i < node.values.size - 1
              sb << "), "
            else
              sb << ")"
            end
          end
          if node.back.any?
            sb << " RETURNING ("
            node.back.each_with_index do |column, i|
              sb << column.accept(self)
              sb << ", " if i < node.back.size - 1
            end
            sb << ")"
          end
        end
      end
    end

    def visit(node : Delete) : String
      String::Builder.build do |sb|
        sb << "DELETE FROM "
        sb << node.table.accept(self)
        if using = node.using
          sb << " USING " << using.accept(self)
        end
        sb << node.where.not_nil!.accept(self) if node.where
        if node.back.any?
          sb << " RETURNING ("
          node.back.each_with_index do |column, i|
            sb << column.accept(self)
            sb << ", " if i < node.back.size - 1
          end
          sb << ")"
        end
      end
    end

    def visit(node : Where) : String
      String::Builder.build do |sb|
        sb << " WHERE ("
        sb << node.condition.accept(self)
        sb << ")"
      end
    end

    def visit(node : Column) : String
      String::Builder.build do |sb|
        unless node.column.name == :*
          sb << node.column.table.not_nil!.table_name
          sb << "."
        end
        sb << node.column.name
      end
    end

    def visit(node : And) : String
      String::Builder.build do |sb|
        sb << node.left.accept(self)
        sb << " AND "
        sb << node.right.accept(self)
      end
    end

    def visit(node : Or) : String
      String::Builder.build do |sb|
        sb << node.left.accept(self)
        sb << " OR "
        sb << node.right.accept(self)
      end
    end

    def visit(node : Not) : String
      String::Builder.build do |sb|
        sb << "NOT "
        sb << node.condition.accept(self)
      end
    end

    def visit(node : Compare) : String
      String::Builder.build do |sb|
        sb << node.left.accept(self)
        sb << " "
        sb << node.operator
        sb << " "
        sb << node.right.to_s
      end
    end

    def visit(node : CompareCondition) : String
      String::Builder.build do |sb|
        if node.left.is_a?(Column) || node.left.is_a?(Condition)
          sb << node.left.as(Column | Condition).accept(self)
        else
          sb << node.left.to_s
        end
        sb << " "
        sb << node.operator
        sb << " "
        if node.right.is_a?(Column) || node.right.is_a?(Condition)
          sb << node.right.as(Column | Condition).accept(self)
        else
          sb << node.right.to_s
        end
      end
    end

    def visit(node : Between) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " BETWEEN "
        sb << node.low.to_s
        sb << " AND "
        sb << node.high.to_s
      end
    end

    def visit(node : Like) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " LIKE "
        sb << node.value
      end
    end

    def visit(node : NotLike) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " NOT LIKE "
        sb << node.value
      end
    end

    def visit(node : InCondition) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " IN ("
        node.values.each_with_index do |value, i|
          sb << value.to_s
          sb << ", " if i < node.values.size - 1
        end
        sb << ")"
      end
    end

    def visit(node : OrderBy) : String
      return "" if node.orders.empty?
      String::Builder.build do |sb|
        sb << " ORDER BY "
        node.orders.each_with_index do |(column, direction), i|
          sb << column.accept(self)
          sb << " "
          sb << direction.to_s.upcase
          sb << ", " if i < node.orders.size - 1
        end
      end
    end

    def visit(node : GroupBy) : String
      return "" if node.columns.empty?

      String::Builder.build do |sb|
        sb << " GROUP BY "
        node.columns.each_with_index do |column, i|
          sb << column.accept(self)
          sb << ", " if i < node.columns.size - 1
        end
      end
    end

    def visit(node : InSelect) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " IN ("
        sb << node.query.accept(self)
        sb << ")"
      end
    end

    def visit(node : Exists) : String
      String::Builder.build do |sb|
        sb << "EXISTS ("
        sb << node.sub_query.accept(self)
        sb << ")"
      end
    end

    def visit(node : Having) : String
      String::Builder.build do |sb|
        sb << " HAVING "
        sb << node.condition.accept(self)
      end
    end

    def visit(node : Limit) : String
      String::Builder.build do |sb|
        sb << " LIMIT "
        sb << node.limit.to_s
        sb << " OFFSET " << node.offset.to_s if node.offset
      end
    end

    def visit(node : Top) : String
      String::Builder.build do |sb|
        sb << "TOP "
        sb << node.count.to_s
      end
    end

    def visit(node : From) : String
      String::Builder.build do |sb|
        sb << " FROM "
        node.tables.each_with_index do |table, i|
          sb << table.table_name
          sb << " AS " << table.as_name if table.as_name
          sb << ", " if i < node.tables.size - 1
        end
      end
    end

    def visit(node : Table) : String
      node.table.table_name.to_s
    end

    def visit(node : Null) : String
      String::Builder.build do |sb|
        sb << "NULL"
        if column = node.column
          sb << column.accept(self)
        end
      end
    end

    def visit(node : Is) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " IS "
        sb << node.value.to_s
      end
    end

    def visit(node : IsNull) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " IS NULL"
      end
    end

    def visit(node : IsNot) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " IS NOT "
        sb << node.value.to_s
      end
    end

    def visit(node : IsNotNull) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " IS NOT NULL"
      end
    end

    def visit(node : EmptyNode) : String
      ""
    end

    def visit(node : Count) : String
      String::Builder.build do |sb|
        sb << "COUNT("
        sb << node.column.accept(self)
        sb << ")"
      end
    end

    def visit(node : Max) : String
      String::Builder.build do |sb|
        sb << "MAX("
        sb << node.column.accept(self)
        sb << ")"
      end
    end

    def visit(node : Min) : String
      String::Builder.build do |sb|
        sb << "MIN("
        sb << node.column.accept(self)
        sb << ")"
      end
    end

    def visit(node : Avg) : String
      String::Builder.build do |sb|
        sb << "AVG("
        sb << node.column.accept(self)
        sb << ")"
      end
    end

    def visit(node : Sum) : String
      String::Builder.build do |sb|
        sb << "SUM("
        sb << node.column.accept(self)
        sb << ")"
      end
    end

    def visit(node : Setter) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " = "
        sb << node.value.to_s
      end
    end

    def visit(node : Update) : String
      String::Builder.build do |sb|
        sb << "UPDATE "
        sb << node.table.accept(self)
        sb << " SET "
        node.setters.each_with_index do |setter, i|
          sb << setter.accept(self)
          sb << ", " if i < node.setters.size - 1
        end
        if where = node.where
          sb << where.accept(self)
        end
        if node.back.any?
          sb << " RETURNING "
          node.back.each_with_index do |column, i|
            sb << column.accept(self)
            sb << ", " if i < node.back.size - 1
          end
        end
      end
    end

    def visit(node : CreateIndex) : String
      String::Builder.build do |sb|
        sb << "CREATE "
        sb << "UNIQUE " if node.index.unique
        sb << "INDEX "
        sb << node.index.index_name
        sb << " ON "
        sb << node.index.table.table_name
        sb << " ("
        sb << node.index.columns.map { |c| c.to_s }.join(", ")
        sb << ")"
      end
    end

    def visit(node : CreateTable) : String
      String::Builder.build do |sb|
        sb << "CREATE TABLE IF NOT EXISTS "
        sb << node.table.table_name
        sb << " ("
        node.table.columns.each_with_index do |(name, column), i|
          sb << column.name
          sb << " " << column.sql_type(@adapter)
          sb << " PRIMARY KEY" if column.is_a?(Sql::PrimaryKey)
          sb << " NOT NULL" unless column.null?
          sb << " UNIQUE" if column.unique
          sb << ", " if i < node.table.columns.size - 1
        end
        sb << ")"
      end
    end

    def visit(node : DropTable) : String
      String::Builder.build do |sb|
        sb << "DROP TABLE IF EXISTS "
        sb << node.table.table_name
      end
    end

    def visit(node : TruncateTable) : String
      String::Builder.build do |sb|
        sb << "TRUNCATE TABLE "
        sb << node.table.table_name
      end
    end

    # Add support for AlterTable
    def visit(node : AlterTable) : String
      String::Builder.build do |sb|
        sb << "ALTER TABLE "
        sb << node.table.table_name
        sb << " "
        sb << node.action.accept(self)
      end
    end

    def visit(node : AddColumn) : String
      String::Builder.build do |sb|
        sb << "ADD COLUMN "
        sb << node.column.name
        sb << " " << node.column.sql_type(@adapter)
        sb << " PRIMARY KEY" if node.column.is_a?(Sql::PrimaryKey)
        sb << " NOT NULL" unless node.column.null?
        sb << " UNIQUE" if node.column.unique
      end
    end

    def visit(node : DropColumn) : String
      String::Builder.build do |sb|
        sb << "DROP COLUMN "
        sb << node.column_name
      end
    end

    def visit(node : DropIndex) : String
      @dialect.drop_index(node.index.index_name, node.index.table.table_name.to_s)
    end

    def visit(node : RenameColumn) : String
      @dialect.rename_column(
        node.table_name,
        node.old_name,
        node.new_name,
        node.column.sql_type(@adapter)
      )
    end

    def visit(node : RenameTable) : String
      @dialect.rename_table(node.table.table_name.to_s, node.new_name)
    end
  end
end
