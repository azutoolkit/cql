require "./expressions"
require "./visitor"

module Expression
  class Generator
    include Visitor
    @dialect : BaseDialect
    getter params : Array(DB::Any) = [] of DB::Any
    getter query : String = ""

    def initialize(@adapter : CQL::Adapter = CQL::Adapter::SQLite, @quote_identifiers : Bool = false)
      @dialect = @adapter.dialect
    end

    # A table, column or alias name as it appears in SQL: quoted when the
    # schema opted in, verbatim otherwise.
    private def ident(name) : String
      @quote_identifiers ? @dialect.quote_identifier(name.to_s) : name.to_s
    end

    # Helper method to check if a column is an auto-timestamp column
    private def is_auto_timestamp_column?(column : CQL::BaseColumn) : Bool
      column_name = column.name.to_s
      %w[created_at updated_at].includes?(column_name)
    end

    # Visits only append to the parameters; `reset` (called by every `to_sql`)
    # is the one place they are cleared, so subqueries keep the outer values.
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
      @query = String.build do |string|
        string << with_clause(node)
        string << "SELECT "
        string << "DISTINCT " if node.distinct? && node.distinct_on.empty?
        string << @dialect.format_distinct_on(node.distinct_on.map(&.accept(self))) unless node.distinct_on.empty?
        # Columns and select expressions (aggregates, window functions), aliased where given
        if node.columns.empty? && node.select_expressions.empty?
          string << "*"
        else
          node.columns.each_with_index do |column, index|
            string << ", " if index > 0
            string << column.accept(self)
          end
          node.select_expressions.each_with_index do |expression, index|
            string << ", " if index > 0 || !node.columns.empty?
            string << select_item(expression)
          end
        end

        # From node now contains Expression::Table nodes potentially with aliases
        string << node.from.accept(self)
        # Join nodes now contain Expression::Table nodes potentially with aliases
        node.joins.each { |join| string << join.accept(self) }
        string << node.where.try &.accept(self) if node.where       # Where conditions handle aliases internally
        string << node.group_by.try &.accept(self) if node.group_by # GroupBy handles aliases internally
        string << node.having.try &.accept(self) if node.having     # Having handles aliases internally
        string << node.order_by.try &.accept(self) if node.order_by # OrderBy handles aliases internally
        string << node.limit.try &.accept(self) if node.limit
        node.lock.try { |lock| string << @dialect.format_lock(lock) }
      end
    end

    # An aggregate or window function in the SELECT list, with its optional `AS alias`.
    private def select_item(expression : SelectExpression) : String
      sql = expression.accept(self)
      (name = expression.as_name) ? "#{sql} AS #{ident(name)}" : sql
    end

    def visit(node : Join) : String
      String.build do |string|
        string << @dialect.join_keyword(node.join_type)
        # table node needs to output alias if present
        string << node.table.accept(self)
        unless node.join_type.cross?
          string << " ON "
          # condition node needs to output aliased columns if present
          string << node.condition.accept(self)
        end
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
          string << ident(col.column.name)
          string << ", " if i < columns.size - 1
        end
        string << ")"

        if q = node.query
          raise ArgumentError.new("ON CONFLICT is not supported with INSERT ... SELECT") if node.conflict
          string << " " << q.accept(self)
        else
          # Store placeholders for values
          placeholders = [] of String

          # Add all values to params and collect placeholders
          node.values.each do |row|
            row.each do |val|
              placeholders << bind(val)
            end
          end

          # Use dialect to format insert values
          string << @dialect.format_insert_values(node.values, placeholders)
          node.conflict.try { |conflict| string << conflict.accept(self) }

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
      column_reference(node)
    end

    def visit(node : BaseColumn) : String
      column_reference(node)
    end

    def visit(node : TypedColumn) : String
      # TypedColumn behaves the same as Column for SQL generation
      column_reference(node)
    end

    # `qualifier.column` for a column expression. The qualifier is the table
    # alias when one is set, otherwise the column's own table name.
    private def column_reference(node : BaseColumn) : String
      column_name = node.column.name
      if alias_name = node.alias_name
        column_name == :* ? "#{ident(alias_name)}.*" : "#{ident(alias_name)}.#{ident(column_name)}"
      elsif column_name == :*
        # SELECT * - the query builder expands it when specific tables are needed
        "*"
      else
        table = node.column.table
        raise "Internal Error: Column expression missing table context and no alias provided" unless table
        "#{ident(table.table_name)}.#{ident(column_name)}"
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

    # Always parenthesized: `NOT a AND b` would negate only `a`.
    def visit(node : Not) : String
      "NOT (#{node.condition.accept(self)})"
    end

    def visit(node : Compare) : String
      String.build do |string|
        # Left side is an Expression::Column, which now handles alias
        string << node.left.accept(self)
        string << " "
        string << node.operator
        string << " "
        string << bind(node.right)
      end
    end

    def visit(node : CompareCondition) : String
      String.build do |string|
        # Left and Right can be Expression::BaseColumn (now alias-aware)
        # or DB::Any (which becomes a placeholder)
        if node.left.is_a?(Expression::BaseColumn) || node.left.is_a?(Condition)
          string << node.left.as(Expression::BaseColumn | Condition).accept(self)
        else
          string << bind(node.left.as(DB::Any))
        end
        string << " "
        string << node.operator
        string << " "
        if node.right.is_a?(Expression::BaseColumn) || node.right.is_a?(Condition)
          string << node.right.as(Expression::BaseColumn | Condition).accept(self)
        else
          string << bind(node.right.as(DB::Any))
        end
      end
    end

    def visit(node : Cte) : String
      "#{ident(node.name)} AS (#{node.statement.accept(self)})"
    end

    private def with_clause(node : Query) : String
      return "" if node.ctes.empty?
      "WITH #{"RECURSIVE " if node.recursive?}#{node.ctes.join(", ", &.accept(self))} "
    end

    def visit(node : WindowFunction) : String
      clauses = [partition_clause(node), node.order_by.try(&.accept(self).strip), node.frame.try { |frame| frame_clause(frame) }]
      "#{window_call(node)} OVER (#{clauses.compact.join(" ")})"
    end

    private def window_call(node : WindowFunction) : String
      column = node.column.try(&.accept(self)) || (node.kind.count? ? "*" : nil)
      arguments = node.kind.ntile? ? [node.argument] : [column, node.argument]
      "#{node.kind.to_sql}(#{arguments.compact.join(", ")})"
    end

    private def partition_clause(node : WindowFunction) : String?
      "PARTITION BY #{node.partition_by.join(", ", &.accept(self))}" unless node.partition_by.empty?
    end

    private def frame_clause(frame : Frame) : String
      "#{frame.unit.to_s.upcase} BETWEEN #{frame_bound(frame.from)} AND #{frame_bound(frame.to)}"
    end

    private def frame_bound(bound : Frame::Bound) : String
      case bound
      in Symbol then bound.to_s.tr("_", " ").upcase
      in Int32  then bound.zero? ? "CURRENT ROW" : "#{bound.abs} #{bound < 0 ? "PRECEDING" : "FOLLOWING"}"
      end
    end

    def visit(node : JsonEquals) : String
      column = node.column.accept(self)
      path = bind(@dialect.json_path_param(node.path))
      "#{@dialect.format_json_text(column, path)} = #{bind(@dialect.json_text_value(node.value))}"
    end

    def visit(node : JsonContains) : String
      @dialect.format_json_contains(node.column.accept(self), bind(node.json))
    end

    def visit(node : GeoWithin) : String
      column = node.column.accept(self)
      @dialect.format_geo_within(column, bind(node.longitude), bind(node.latitude), bind(node.meters))
    end

    def visit(node : OnConflict) : String
      target = node.target.map { |column| ident(column.column.name) }
      return @dialect.format_on_conflict_nothing(target) if node.do_nothing?

      refreshed = node.refreshed.map { |column| name = ident(column.column.name); "#{name} = #{@dialect.excluded_reference(name)}" }
      @dialect.format_on_conflict_update(target, refreshed + node.assignments.map(&.accept(self)))
    end

    def visit(node : SetOperation) : String
      @query = "#{set_operand(node.left)} #{node.operator.to_sql} #{set_operand(node.right)}"
    end

    # Operands that are themselves set operations, or that carry ORDER BY /
    # LIMIT, are grouped so those clauses stay on the operand and the chain keeps
    # its left-to-right meaning (INTERSECT otherwise binds tighter).
    private def set_operand(node : Statement) : String
      sql = node.accept(self)
      node.needs_grouping_as_operand? ? @dialect.wrap_compound_operand(sql) : sql
    end

    def visit(node : Raw) : String
      String.build do |sql|
        node.fragments.each_with_index do |fragment, index|
          sql << fragment
          append_binding(sql, node.bindings[index]) if index < node.bindings.size
        end
      end
    end

    # Binds one value, or a comma-separated list of placeholders for an array.
    private def append_binding(sql : IO, value : Raw::Value) : Nil
      case value
      when Array then value.join(sql, ", ") { |item, io| io << bind(item) }
      else            sql << bind(value)
      end
    end

    private def bind(value : DB::Any) : String
      @params << value
      placeholder
    end

    def visit(node : Between) : String
      low_placeholder = bind(node.low)

      high_placeholder = bind(node.high)

      String.build do |string|
        string << node.column.accept(self)
        string << " BETWEEN "
        string << low_placeholder
        string << " AND "
        string << high_placeholder
      end
    end

    def visit(node : Like) : String
      column = node.column.accept(self)
      node.insensitive? ? @dialect.format_ilike(column, bind(node.value)) : @dialect.format_like(column, bind(node.value))
    end

    def visit(node : NotLike) : String
      column = node.column.accept(self)
      node.insensitive? ? @dialect.format_not_ilike(column, bind(node.value)) : @dialect.format_not_like(column, bind(node.value))
    end

    def visit(node : InCondition) : String
      String.build do |string|
        # Column node handles alias
        string << node.column.accept(self)
        string << " IN ("
        node.values.each_with_index do |value, i|
          string << bind(value)
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
      unless node.limit
        # OFFSET with no LIMIT: the dialect decides how to express "unbounded".
        return @dialect.format_offset_only(bind(node.offset.not_nil!))
      end

      limit_placeholder = bind(node.limit)

      offset_placeholder = nil
      if node.offset
        offset_placeholder = bind(node.offset)
      end

      @dialect.format_limit_offset(limit_placeholder, offset_placeholder)
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
        string << ident(table_name)
        # Only add AS clause if alias is different from the table name
        if alias_name = node.alias_name
          if alias_name != table_name
            string << " AS " << ident(alias_name)
          end
        end
      end
    end

    def visit(node : Subquery) : String
      "(#{node.statement.accept(self)}) AS #{ident(node.alias_name)}"
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
      "#{node.column.accept(self)} IS #{bind(node.value)}"
    end

    def visit(node : IsNull) : String
      # Column node handles alias
      @dialect.format_is_null(node.column.accept(self))
    end

    def visit(node : IsNot) : String
      "#{node.column.accept(self)} IS NOT #{bind(node.value)}"
    end

    def visit(node : IsNotNull) : String
      # Column node handles alias
      @dialect.format_is_not_null(node.column.accept(self))
    end

    def visit(node : EmptyNode) : String
      ""
    end

    def visit(node : Count) : String
      # COUNT(*) for the special '*' placeholder, otherwise the column (alias-aware)
      counted = node.column.column.name == :* ? "*" : node.column.accept(self)
      @dialect.format_count(node.distinct? ? "DISTINCT #{counted}" : counted)
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
      "#{ident(node.column.column.name)} = #{bind(node.value)}"
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
      index = node.index
      args = {
        validate_index_name!(index.index_name),
        index.table.table_name.to_s,
        index.columns.map(&.to_s),
        index.unique?,
      }
      @query = node.if_not_exists? ? @dialect.create_index_if_not_exists(*args) : @dialect.create_index(*args)
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
              is_auto_timestamp_column?(column)
            )
          end
        end
        definitions.concat(columns_sql)

        # Define foreign keys (if any)
        unless node.table.foreign_keys.empty?
          fks_sql = node.table.foreign_keys.map do |foreign_key|
            validate_foreign_key!(foreign_key)
            @dialect.define_foreign_key(foreign_key)
          end
          definitions.concat(fks_sql)
        end

        # Define unique constraints (if any)
        unless node.table.unique_constraints.empty?
          unique_sql = node.table.unique_constraints.map do |unique_constraint|
            validate_optional!(unique_constraint.name, "unique constraint name")
            unique_constraint.columns.each { |col| CQL::Identifier.validate!(col.to_s, "column name") }
            @dialect.define_unique_constraint(unique_constraint)
          end
          definitions.concat(unique_sql)
        end

        # Define check constraints (if any)
        unless node.table.check_constraints.empty?
          check_sql = node.table.check_constraints.map do |check_constraint|
            validate_optional!(check_constraint.name, "check constraint name")
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
      @dialect.drop_index(CQL::Identifier.validate_qualified!(node.index.index_name.to_s, "index name"), node.index.table.table_name.to_s)
    end

    def visit(node : RenameColumn) : String
      @dialect.rename_column(
        node.table_name,
        CQL::Identifier.validate!(node.old_name.to_s, "column name"),
        CQL::Identifier.validate!(node.new_name.to_s, "column name"),
        node.column.type,
      )
    end

    def visit(node : RenameTable) : String
      @dialect.rename_table(node.table.table_name.to_s, CQL::Identifier.validate!(node.new_name.to_s, "table name"))
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

      validate_foreign_key!(node.fk)
      @dialect.add_foreign_key(
        CQL::Identifier.validate!(node.fk.name || "fk_#{node.fk.table.table_name}_#{node.fk.columns.join("_")}", "foreign key name"), # Provide default name if nil
        node.fk.table.table_name.to_s,
        node.fk.columns.map(&.to_s),
        node.fk.references_table.to_s,
        node.fk.references_columns.map(&.to_s),
        on_delete_sql, # Use formatted SQL string
        on_update_sql  # Use formatted SQL string
      )
    end

    # Foreign key parts that are spliced into DDL as identifiers.
    private def validate_foreign_key!(fk : CQL::ForeignKey) : Nil
      validate_optional!(fk.name, "foreign key name")
      fk.columns.each { |col| CQL::Identifier.validate!(col.to_s, "column name") }
      CQL::Identifier.validate!(fk.references_table.to_s, "table name")
      fk.references_columns.each { |col| CQL::Identifier.validate!(col.to_s, "column name") }
    end

    # PostgreSQL truncates longer names (and IF NOT EXISTS can then skip a different index); MySQL rejects them.
    private def validate_index_name!(name : String) : String
      CQL::Identifier.validate!(name, "index name")
      return name if name.size <= CQL::Index::MAX_NAME_LENGTH
      raise ArgumentError.new("Index name #{name.inspect} is longer than #{CQL::Index::MAX_NAME_LENGTH} characters; give the index a shorter name")
    end

    private def validate_optional!(name : String?, kind : String) : Nil
      CQL::Identifier.validate!(name, kind) if name
    end

    def visit(node : DropForeignKey) : String
      @dialect.drop_foreign_key(node.table, CQL::Identifier.validate!(node.fk, "foreign key name"))
    end
  end
end
