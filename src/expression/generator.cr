require "./expressions"
require "./visitor"

module Expression
  class Generator
    include Visitor
    @dialect : BaseDialect
    getter params : Array(DB::Any) = [] of DB::Any
    getter query : String = ""

    def initialize(@adapter : CQL::Adapter = CQL::Adapter::SQLite)
      @dialect = @adapter.dialect
    end

    def reset
      @params.clear
      @query = ""
    end

    # Get the appropriate placeholder based on the current parameter index
    # This delegates to the dialect's placeholder_format method
    private def placeholder : String
      @dialect.placeholder_format(@params.size)
    end

    # Template Method for common visit methods
    def visit(node : Query) : String
      @params.clear
      @query = String.build do |string|
        string << "SELECT "
        string << "DISTINCT " if node.distinct?
        # Columns and aggregates now contain Expression::Column nodes potentially with aliases
        columns_sql = node.columns.map(&.accept(self))
        aggr_sql = node.aggr_columns.map(&.accept(self))

        select_parts = columns_sql + aggr_sql
        string << select_parts.join(", ")

        # From node now contains Expression::Table nodes potentially with aliases
        string << node.from.accept(self)
        # Join nodes now contain Expression::Table nodes potentially with aliases
        node.joins.each { |join| string << join.accept(self) }
        string << node.where.try &.accept(self) if node.where       # Where conditions handle aliases internally
        string << node.group_by.try &.accept(self) if node.group_by # GroupBy handles aliases internally
        string << node.having.try &.accept(self) if node.having     # Having handles aliases internally
        string << node.order_by.try &.accept(self) if node.order_by # OrderBy handles aliases internally
        string << node.limit.try &.accept(self) if node.limit
      end
    end

    def visit(node : Join) : String
      String.build do |string|
        string << " #{node.join_type.to_s.upcase} JOIN "
        # table node needs to output alias if present
        string << node.table.accept(self)
        string << " ON "
        # condition node needs to output aliased columns if present
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
          # Store placeholders for values
          placeholders = [] of String

          # Add all values to params and collect placeholders
          node.values.each do |row|
            row.each do |val|
              @params << val
              placeholders << placeholder
            end
          end

          # Use dialect to format insert values
          string << @dialect.format_insert_values(node.values, placeholders)

          # Handle returning clause if needed
          if !node.back.empty?
            column_names = node.back.map(&.accept(self))
            string << @dialect.format_returning(column_names)
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
          column_names = node.back.map(&.accept(self))
          string << @dialect.format_delete_returning(column_names)
        end
      end
    end

    def visit(node : Where) : String
      String.build do |string|
        string << " WHERE "                   # Remove parens, they might interfere with precedence
        string << node.condition.accept(self) # Condition handles aliases internally
      end
    end

    def visit(node : Column) : String
      # Assuming Expression::Column now has `alias_name : Symbol?` field
      String.build do |string|
        if alias_name = node.alias_name
          # Use alias if provided
          string << alias_name
          string << "."
          string << node.column.name
        elsif node.column.name == :*
          # Handle SELECT *
          # If an alias exists on the * Column itself (unlikely but possible), use it
          # Otherwise, just output '*' - the Query builder should have expanded it if specific tables were needed.
          string << "*"
        else
          # No alias provided on the column expression, use the original table name
          table = node.column.table
          raise "Internal Error: Column expression missing table context and no alias provided" unless table
          string << table.table_name
          string << "."
          string << node.column.name
        end
      end
    end

    def visit(node : And) : String
      String.build do |string|
        # Wrap sides in parentheses for correct precedence
        string << "(" << node.left.accept(self) << ")"
        string << " AND "
        string << "(" << node.right.accept(self) << ")"
      end
    end

    def visit(node : Or) : String
      String.build do |string|
        # Wrap sides in parentheses for correct precedence
        string << "(" << node.left.accept(self) << ")"
        string << " OR "
        string << "(" << node.right.accept(self) << ")"
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
        # Left side is an Expression::Column, which now handles alias
        string << node.left.accept(self)
        string << " "
        string << node.operator
        string << " "
        string << placeholder
      end
    end

    def visit(node : CompareCondition) : String
      String.build do |string|
        # Left and Right can be Expression::Column (now alias-aware)
        # or DB::Any (which becomes a placeholder)
        if node.left.is_a?(Expression::Column) || node.left.is_a?(Condition)
          string << node.left.as(Expression::Column | Condition).accept(self)
        else
          @params << node.left.as(DB::Any)
          string << placeholder
        end
        string << " "
        string << node.operator
        string << " "
        if node.right.is_a?(Expression::Column) || node.right.is_a?(Condition)
          string << node.right.as(Expression::Column | Condition).accept(self)
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
        # Column node handles alias
        string << node.column.accept(self)
        string << " BETWEEN "
        string << placeholder
        string << " AND "
        string << placeholder
      end
    end

    def visit(node : Like) : String
      @params << node.value
      # Column node handles alias
      @dialect.format_like(node.column.accept(self), placeholder)
    end

    def visit(node : NotLike) : String
      @params << node.value
      # Column node handles alias
      @dialect.format_not_like(node.column.accept(self), placeholder)
    end

    def visit(node : InCondition) : String
      String.build do |string|
        # Column node handles alias
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
        # Column nodes handle alias
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
        # Column nodes handle alias
        node.columns.each_with_index do |column, i|
          string << column.accept(self)
          string << ", " if i < node.columns.size - 1
        end
      end
    end

    def visit(node : InSelect) : String
      String.build do |string|
        # Column node handles alias
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
      # Add params first
      @params << node.limit
      offset_placeholder = nil
      if node.offset
        @params << node.offset
        offset_placeholder = placeholder
      end

      # Use dialect to format limit/offset
      @dialect.format_limit_offset(placeholder, offset_placeholder)
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
        node.tables.each_with_index do |table_expr, i|
          # Table expression visitor now handles alias
          string << table_expr.accept(self)
          string << ", " if i < node.tables.size - 1
        end
      end
    end

    def visit(node : Table) : String
      # Only output alias if it differs from the table name
      String.build do |string|
        table_name = node.table.table_name.to_s
        string << table_name
        # Only add AS clause if alias is different from the table name
        if alias_name = node.alias_name
          if alias_name != table_name
            string << " AS " << alias_name
          end
        end
      end
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
      # Column node handles alias
      "#{node.column.accept(self)} IS #{placeholder}"
    end

    def visit(node : IsNull) : String
      # Column node handles alias
      @dialect.format_is_null(node.column.accept(self))
    end

    def visit(node : IsNot) : String
      @params << node.value
      # Column node handles alias
      "#{node.column.accept(self)} IS NOT #{placeholder}"
    end

    def visit(node : IsNotNull) : String
      # Column node handles alias
      @dialect.format_is_not_null(node.column.accept(self))
    end

    def visit(node : EmptyNode) : String
      ""
    end

    def visit(node : Count) : String
      # Check if the column being counted is the special '*' placeholder
      if node.column.column.name == :*
        # Generate standard COUNT(*) SQL
        @dialect.format_count("*")
      else
        # Otherwise, process the column expression normally (handles aliases)
        @dialect.format_count(node.column.accept(self))
      end
    end

    def visit(node : Max) : String
      # Column node handles alias
      @dialect.format_max(node.column.accept(self))
    end

    def visit(node : Min) : String
      # Column node handles alias
      @dialect.format_min(node.column.accept(self))
    end

    def visit(node : Avg) : String
      # Column node handles alias
      @dialect.format_avg(node.column.accept(self))
    end

    def visit(node : Sum) : String
      # Column node handles alias
      @dialect.format_sum(node.column.accept(self))
    end

    def visit(node : Setter) : String
      @params << node.value
      # If node.column changes to Expression::Column, this needs update
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
          column_names = node.back.map(&.accept(self))
          string << @dialect.format_update_returning(column_names)
        end
      end
    end

    def visit(node : CreateIndex) : String
      @query = @dialect.create_index(
        node.index.index_name.to_s,
        node.index.table.table_name.to_s,
        node.index.columns.map(&.to_s),
        node.index.unique?
      )
    end

    def visit(node : CreateTable) : String
      @query = String.build do |string|
        string << @dialect.create_table_prefix(node.table.table_name.to_s)
        string << " (" # Start columns/constraints definition

        definitions = [] of String

        # Define columns
        columns_sql = node.table.columns.map do |_, column|
          if column.is_a?(CQL::PrimaryKey)
            @dialect.auto_increment_primary_key(column, column.type)
          else
            @dialect.define_column(
              column.name.to_s,
              column.type,
              column.default,
              column.null?,
              column.unique?,
              [:created_at, :updated_at].includes?(column.name) # TODO: This is a hack, remove it
            )
          end
        end
        definitions.concat(columns_sql)

        # Define foreign keys (if any)
        unless node.table.foreign_keys.empty?
          fks_sql = node.table.foreign_keys.map do |foreign_key|
            @dialect.define_foreign_key(foreign_key)
          end
          definitions.concat(fks_sql)
        end

        # Define unique constraints (if any)
        unless node.table.unique_constraints.empty?
          unique_sql = node.table.unique_constraints.map do |unique_constraint|
            @dialect.define_unique_constraint(unique_constraint)
          end
          definitions.concat(unique_sql)
        end

        # Define check constraints (if any)
        unless node.table.check_constraints.empty?
          check_sql = node.table.check_constraints.map do |check_constraint|
            @dialect.define_check_constraint(check_constraint)
          end
          definitions.concat(check_sql)
        end

        string << definitions.join(", ")

        string << ")" # End columns/constraints definition
      end
    end

    def visit(node : DropTable) : String
      @query = @dialect.drop_table(node.table.table_name.to_s)
    end

    def visit(node : TruncateTable) : String
      @query = @dialect.truncate_table(node.table.table_name.to_s)
    end

    # Add support for AlterTable
    def visit(node : AlterTable) : String
      @query = @dialect.alter_table(node.table.table_name.to_s, node.action.accept(self))
    end

    def visit(node : AddColumn) : String
      @dialect.add_column(
        node.column.name.to_s,
        node.column.type,
        node.column.is_a?(CQL::PrimaryKey),
        node.column.null?,
        node.column.unique?
      )
    end

    def visit(node : DropColumn) : String
      @dialect.drop_column(node.column_name.to_s)
    end

    def visit(node : DropIndex) : String
      @dialect.drop_index(node.index.index_name, node.index.table.table_name.to_s)
    end

    def visit(node : RenameColumn) : String
      @dialect.rename_column(
        node.table_name,
        node.old_name,
        node.new_name,
       node.column.type,
      )
    end

    def visit(node : RenameTable) : String
      @dialect.rename_table(node.table.table_name.to_s, node.new_name)
    end

    def visit(node : ChangeColumn) : String
      @dialect.modify_column(
        node.table_name,
        node.column.name.to_s,
        node.column.type,
      )
    end

    def visit(node : AddForeignKey) : String
      if @adapter == CQL::Adapter::SQLite
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

      # Format actions for SQL
      on_delete_sql = node.fk.on_delete.to_s.upcase.gsub("_", " ")
      on_update_sql = node.fk.on_update.to_s.upcase.gsub("_", " ")

      @dialect.add_foreign_key(
        node.fk.name || "fk_#{node.fk.table.table_name}_#{node.fk.columns.join("_")}", # Provide default name if nil
        node.fk.table.table_name.to_s,
        node.fk.columns.map(&.to_s),
        node.fk.references_table.to_s,
        node.fk.references_columns.map(&.to_s),
        on_delete_sql, # Use formatted SQL string
        on_update_sql  # Use formatted SQL string
      )
    end

    def visit(node : DropForeignKey) : String
      @dialect.drop_foreign_key(node.table, node.fk)
    end
  end
end
