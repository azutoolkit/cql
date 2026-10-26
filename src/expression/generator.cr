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

    # Tables and columns keep their quoted names (see `CQL::QuotedNameCache`).
    private def ident(table : CQL::Table) : String
      @quote_identifiers ? table.__quoted_name(@dialect, table.table_name) : table.table_name.to_s
    end

    private def ident(column : CQL::BaseColumn) : String
      @quote_identifiers ? column.__quoted_name(@dialect, column.name) : column.name.to_s
    end

    # An alias that is just the table's name is quoted like the table.
    private def alias_ident(alias_name : String, table : CQL::Table?) : String
      return ident(alias_name) unless table && @quote_identifiers
      table.table_name.to_s == alias_name ? ident(table) : ident(alias_name)
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

    # A statement's clauses write into its one builder through `write(node, io)` instead of each
    # building a String that its parent copies. A node type without its own `write` falls back to
    # its String `visit`; the `visit` of a node that has one is a shim over it.
    private def write(node : Node, io : IO) : Nil
      io << node.accept(self)
    end

    # Defines the String `visit` of each type as a shim over its `write`. A listed type without its
    # own `write` would reach the fallback above, which calls `visit` again, so that fails to compile.
    private macro visit_through_write(*types)
      {% for type in types %}
        def visit(node : {{type}}) : String
          String.build { |io| write(node, io) }
        end
      {% end %}

      macro finished
        \{% for type in {{types}} %}
          \{% unless @type.methods.any? { |method| method.name == "write" && method.args.first.restriction.resolve.id == type.id } %}
            \{% raise "#{@type} lists #{type} in visit_through_write but defines no write(node : #{type}, io)" %}
          \{% end %}
        \{% end %}
      end
    end

    # Query and the statements (Insert, Update, Delete) define `visit` themselves, since it also sets
    # `@query`; so do columns (see `column_sql`).
    visit_through_write Join, Where, Having, From, Table, Subquery, GroupBy, OrderBy,
      And, Or, Not, Compare, CompareCondition, Between, InCondition, InSelect, Exists, Is, IsNot, Raw, Cte,
      Setter

    def visit(node : Query) : String
      @query = String.build { |io| write(node, io) }
    end

    private def write(node : Query, io : IO) : Nil
      write_with_clause(node, io)
      io << "SELECT "
      io << "DISTINCT " if node.distinct? && node.distinct_on.empty?
      io << @dialect.format_distinct_on(node.distinct_on.map(&.accept(self))) unless node.distinct_on.empty?
      write_select_list(node, io)
      write(node.from, io)
      node.joins.each { |join| write(join, io) }
      node.where.try { |where| write(where, io) }
      node.group_by.try { |group_by| write(group_by, io) }
      node.having.try { |having| write(having, io) }
      node.order_by.try { |order_by| write(order_by, io) }
      node.limit.try { |limit| write(limit, io) }
      node.lock.try { |lock| io << @dialect.format_lock(lock) }
    end

    # Columns, then select expressions (aggregates, window functions) with their optional
    # `AS alias`; `*` when there are neither.
    private def write_select_list(node : Query, io : IO) : Nil
      if node.columns.empty? && node.select_expressions.empty?
        io << "*"
        return
      end

      node.columns.each_with_index do |column, index|
        io << ", " if index > 0
        write(column, io)
      end
      node.select_expressions.each_with_index do |expression, index|
        io << ", " if index > 0 || !node.columns.empty?
        write(expression, io)
        expression.as_name.try { |name| io << " AS " << ident(name) }
      end
    end

    private def write(node : Join, io : IO) : Nil
      io << @dialect.join_keyword(node.join_type)
      write(node.table, io)
      return if node.join_type.cross?
      io << " ON "
      write(node.condition, io)
    end

    def visit(node : Insert) : String
      columns = if node.query.nil?
                  node.columns
                else
                  node.query.not_nil!.columns
                end

      @query = String.build do |io|
        io << "INSERT INTO "
        write(node.table, io)
        io << " ("
        columns.each_with_index do |col, i|
          io << ident(col.column)
          io << ", " if i < columns.size - 1
        end
        io << ")"

        if q = node.query
          raise ArgumentError.new("ON CONFLICT is not supported with INSERT ... SELECT") if node.conflict
          io << " "
          write(q, io)
        else
          write_values(node.values, io)
          node.conflict.try { |conflict| write(conflict, io) }

          # Handle returning clause if needed
          if !node.back.empty?
            column_names = node.back.map(&.accept(self))
            io << @dialect.format_returning(column_names)
          end
        end
      end
    end

    def visit(node : Delete) : String
      @query = String.build do |io|
        io << "DELETE FROM "
        write(node.table, io)
        if using = node.using
          io << " USING "
          write(using, io)
        end
        node.where.try { |where| write(where, io) }
        if !node.back.empty?
          column_names = node.back.map(&.accept(self))
          io << @dialect.format_delete_returning(column_names)
        end
      end
    end

    # Values are bound row by row, so `$n` numbering runs across the rows.
    private def write_values(rows : Array(Array(DB::Any)), io : IO) : Nil
      return if rows.empty?
      io << " VALUES "
      rows.each_with_index do |row, row_index|
        io << ", " if row_index > 0
        io << '('
        bind_row(row, io)
        io << ')'
      end
    end

    # Binds a row's values in one step; each placeholder is its value's 1-based position in the
    # parameters, as `bind` gives it.
    private def bind_row(row : Array(DB::Any), io : IO) : Nil
      first = @params.size
      @params.concat(row)
      row.each_index do |index|
        io << ", " if index > 0
        io << @dialect.placeholder_format(first + index + 1)
      end
    end

    private def write(node : Where, io : IO) : Nil
      io << " WHERE "
      write(node.condition, io)
    end

    def visit(node : Column) : String
      column_sql(node)
    end

    def visit(node : BaseColumn) : String
      column_sql(node)
    end

    def visit(node : TypedColumn) : String
      column_sql(node)
    end

    # A column on its own, as the dialect hooks that take a String (LIKE, IS NULL, aggregates) need
    # it: one exactly sized String, where `String.build` would reserve a larger buffer.
    private def column_sql(node : BaseColumn) : String
      qualifier, name = column_parts(node)
      qualifier ? "#{qualifier}.#{name}" : name
    end

    private def write(node : BaseColumn, io : IO) : Nil
      qualifier, name = column_parts(node)
      io << qualifier << '.' if qualifier
      io << name
    end

    # `{alias or table, column}` for a column reference; `{nil, "*"}` for a bare `*`, which the
    # query builder expands when specific tables are needed.
    private def column_parts(node : BaseColumn) : {String?, String}
      column_name = node.column.name
      name = column_name == :* ? "*" : ident(node.column)
      if alias_name = node.alias_name
        {alias_ident(alias_name, node.column.table), name}
      elsif column_name == :*
        {nil, name}
      else
        table = node.column.table
        raise "Internal Error: Column expression missing table context and no alias provided" unless table
        {ident(table), name}
      end
    end

    private def write(node : And, io : IO) : Nil
      write_junction(node.left, " AND ", node.right, io)
    end

    private def write(node : Or, io : IO) : Nil
      write_junction(node.left, " OR ", node.right, io)
    end

    private def write_junction(left : Condition, keyword : String, right : Condition, io : IO) : Nil
      io << "("
      write(left, io)
      io << ")" << keyword << "("
      write(right, io)
      io << ")"
    end

    # Always parenthesized: `NOT a AND b` would negate only `a`.
    private def write(node : Not, io : IO) : Nil
      io << "NOT ("
      write(node.condition, io)
      io << ")"
    end

    private def write(node : Compare, io : IO) : Nil
      write(node.left, io)
      io << ' ' << node.operator << ' ' << bind(node.right)
    end

    # Either side is a column or condition (written) or a value (bound).
    private def write(node : CompareCondition, io : IO) : Nil
      write_operand(node.left, io)
      io << ' ' << node.operator << ' '
      write_operand(node.right, io)
    end

    private def write_operand(operand, io : IO) : Nil
      case operand
      when BaseColumn, Condition then write(operand, io)
      else                            io << bind(operand.as(DB::Any))
      end
    end

    private def write(node : Cte, io : IO) : Nil
      io << ident(node.name) << " AS ("
      write(node.statement, io)
      io << ")"
    end

    private def write_with_clause(node : Query, io : IO) : Nil
      return if node.ctes.empty?
      io << "WITH "
      io << "RECURSIVE " if node.recursive?
      node.ctes.each_with_index do |cte, index|
        io << ", " if index > 0
        write(cte, io)
      end
      io << ' '
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
      target = node.target.map { |column| ident(column.column) }
      return @dialect.format_on_conflict_nothing(target) if node.do_nothing?

      refreshed = node.refreshed.map { |column| name = ident(column.column); "#{name} = #{@dialect.excluded_reference(name)}" }
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

    private def write(node : Raw, io : IO) : Nil
      node.fragments.each_with_index do |fragment, index|
        io << fragment
        append_binding(io, node.bindings[index]) if index < node.bindings.size
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

    private def write(node : Between, io : IO) : Nil
      write(node.column, io)
      io << " BETWEEN " << bind(node.low) << " AND " << bind(node.high)
    end

    def visit(node : Like) : String
      column = node.column.accept(self)
      node.insensitive? ? @dialect.format_ilike(column, bind(node.value)) : @dialect.format_like(column, bind(node.value))
    end

    def visit(node : NotLike) : String
      column = node.column.accept(self)
      node.insensitive? ? @dialect.format_not_ilike(column, bind(node.value)) : @dialect.format_not_like(column, bind(node.value))
    end

    # An empty list matches no row; `IN ()` is a syntax error on PostgreSQL and MySQL.
    private def write(node : InCondition, io : IO) : Nil
      return io << "1 = 0" if node.values.empty?
      write(node.column, io)
      io << " IN ("
      node.values.each_with_index do |value, index|
        io << ", " if index > 0
        io << bind(value)
      end
      io << ")"
    end

    private def write(node : OrderBy, io : IO) : Nil
      return if node.orders.empty?
      io << " ORDER BY "
      node.orders.each_with_index do |(column, direction), index|
        io << ", " if index > 0
        write(column, io)
        io << (direction.asc? ? " ASC" : " DESC")
      end
    end

    private def write(node : GroupBy, io : IO) : Nil
      return if node.columns.empty?
      io << " GROUP BY "
      node.columns.each_with_index do |column, index|
        io << ", " if index > 0
        write(column, io)
      end
    end

    private def write(node : InSelect, io : IO) : Nil
      write(node.column, io)
      io << " IN ("
      write(node.query, io)
      io << ")"
    end

    private def write(node : Exists, io : IO) : Nil
      io << "EXISTS ("
      write(node.sub_query, io)
      io << ")"
    end

    private def write(node : Having, io : IO) : Nil
      io << " HAVING "
      write(node.condition, io)
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

    private def write(node : From, io : IO) : Nil
      io << " FROM "
      node.tables.each_with_index do |table, index|
        io << ", " if index > 0
        write(table, io)
      end
    end

    # `AS alias` only when the alias differs from the table name.
    private def write(node : Table, io : IO) : Nil
      table_name = node.table.table_name.to_s
      io << ident(node.table)
      alias_name = node.alias_name
      io << " AS " << ident(alias_name) if alias_name && alias_name != table_name
    end

    private def write(node : Subquery, io : IO) : Nil
      io << "("
      write(node.statement, io)
      io << ") AS " << ident(node.alias_name)
    end

    def visit(node : Null) : String
      String.build do |string|
        string << "NULL"
        if column = node.column
          string << column.accept(self)
        end
      end
    end

    private def write(node : Is, io : IO) : Nil
      write(node.column, io)
      io << " IS " << bind(node.value)
    end

    def visit(node : IsNull) : String
      # Column node handles alias
      @dialect.format_is_null(node.column.accept(self))
    end

    private def write(node : IsNot, io : IO) : Nil
      write(node.column, io)
      io << " IS NOT " << bind(node.value)
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

    private def write(node : Setter, io : IO) : Nil
      io << ident(node.column.column) << " = " << bind(node.value)
    end

    def visit(node : Update) : String
      @query = String.build do |io|
        io << "UPDATE "
        write(node.table, io)
        io << " SET "
        node.setters.each_with_index do |setter, index|
          io << ", " if index > 0
          write(setter, io)
        end
        node.where.try { |where| write(where, io) }
        if !node.back.empty?
          column_names = node.back.map(&.accept(self))
          io << @dialect.format_update_returning(column_names)
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
