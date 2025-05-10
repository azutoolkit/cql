# Contains internal helper methods for query building and management.
# Note: These methods access instance variables directly as they are included.
module InternalHelpers
  private def build_from
    from_table_aliases = @query_tables.keys.reject do |table_alias_str|
      @joins.any? { |j| j.table.alias_name == table_alias_str }
    end
    from_tables_info = from_table_aliases.map { |alias_str| @query_tables[alias_str] }
    from_table_expressions = from_tables_info.map { |info| Expression::Table.new(info[:table], info[:alias]) }
    Expression::From.new(from_table_expressions)
  end

  private def build_condition_from_hash(hash : Hash(Symbol | String, DB::Any))
    condition = nil
    hash.each_with_index do |(k, v), index|
      expr = get_expression(k, v)
      condition = index == 0 ? expr : Expression::And.new(condition.not_nil!, expr)
    end
    condition.not_nil!
  end

  private def merge_where_condition(new_condition)
    if @where.nil?
      @where = Expression::Where.new(new_condition)
    else
      merged_condition = Expression::And.new(@where.not_nil!.condition, new_condition)
      @where = Expression::Where.new(merged_condition)
    end
  end

  # Handles String field (qualified or unqualified)
  private def get_expression(field : Symbol | String, value)
    column = find_column(field)
    col_alias_str = find_alias_for_table(column.table.not_nil!)
    column.validate!(value)
    Expression::Compare.new(Expression::Column.new(column, alias_name: col_alias_str), "=", value)
  end

  private def build_group_by
    return nil if @group_by.empty?
    group_cols = @group_by.map do |base_col|
      col_alias_str = find_alias_for_table(base_col.table.not_nil!)
      Expression::Column.new(base_col, alias_name: col_alias_str)
    end
    Expression::GroupBy.new(group_cols)
  end

  private def build_order_by
    return nil if @order_by.empty?
    order_exprs = @order_by.map do |base_col, direction|
      col_alias_str = find_alias_for_table(base_col.table.not_nil!)
      {Expression::Column.new(base_col, alias_name: col_alias_str), direction}
    end.to_h
    Expression::OrderBy.new(order_exprs)
  end

  private def build_limit
    Expression::Limit.new(@limit, @offset) if @limit
  end

  private def build_select
    selected_columns = [] of Expression::Column
    aggregate_expressions = [] of Expression::Aggregate

    @aggr_columns.each do |aggr_node|
      aggregate_expressions << aggr_node
    end

    if @columns.empty? && aggregate_expressions.empty?
      if @query_tables.empty?
        return {[] of Expression::Column, [] of Expression::Aggregate}
      end
      @query_tables.each do |table_alias_str, info|
        table = info[:table]
        table.columns.each_value do |base_col|
          selected_columns << Expression::Column.new(base_col, alias_name: table_alias_str)
        end
        pk = table.primary
        if pk && !table.columns.has_key?(pk.name)
          selected_columns << Expression::Column.new(pk, alias_name: table_alias_str)
        end
      end
    else
      selected_columns = @columns.map do |base_col|
        table = base_col.table.not_nil!
        col_alias_str = find_alias_for_table(table)
        Expression::Column.new(base_col, alias_name: col_alias_str)
      end
    end

    selected_columns.uniq! do |col_expr|
      "#{col_expr.alias_name}.#{col_expr.column.name}"
    end

    {selected_columns, aggregate_expressions}
  end

  private def find_schema_table(name : Symbol) : CQL::Table
    table = @schema.tables[name]?
    raise ArgumentError.new("Table '#{name}' not found in schema") unless table
    table
  end

  # Builds aggregate expression with String alias in the inner Expression::Column
  private def build_aggr_expression(aggr : Symbol, column_name : Symbol | String)
    base_col = find_column(column_name)
    col_alias_str = find_alias_for_table(base_col.table.not_nil!)
    col_expr = Expression::Column.new(base_col, alias_name: col_alias_str)
    case aggr
    when :count then Expression::Count.new(col_expr)
    when :sum   then Expression::Sum.new(col_expr)
    when :avg   then Expression::Avg.new(col_expr)
    when :min   then Expression::Min.new(col_expr)
    when :max   then Expression::Max.new(col_expr)
    else
      raise ArgumentError.new "Invalid aggregate function #{aggr}"
    end
  end

  # Finds BaseColumn based on String or Symbol name (potentially qualified), uses String alias hint
  # Returns the BaseColumn associated with the correct table/alias.
  private def find_column(name_or_qualified : Symbol | String, table_alias_hint : String? = nil) : CQL::BaseColumn
    search_alias_str : String? = table_alias_hint
    column_name_str : String? = nil

    case name_or_qualified
    when String
      parts = name_or_qualified.split('.', 2)
      if parts.size == 2
        search_alias_str = parts[0]
        column_name_str = parts[1]
      else
        column_name_str = name_or_qualified
        search_alias_str = table_alias_hint
      end
    when Symbol
      column_name_str = name_or_qualified.to_s
      search_alias_str = table_alias_hint
    end

    unless column_name_str
      raise ArgumentError.new("Invalid column identifier: #{name_or_qualified}")
    end

    if search_alias_str
      table_info = @query_tables[search_alias_str]?
      raise ArgumentError.new "Table or alias '#{search_alias_str}' not found in query tables: #{@query_tables.keys.join(", ")}" unless table_info
      column = find_column_in_table(table_info[:table], column_name_str)
      raise ArgumentError.new "Column '#{column_name_str}' not found in table/alias '#{search_alias_str}'" unless column
      column.tap(&.table=(table_info[:table]))
    else
      found_column : CQL::BaseColumn? = nil
      found_in_alias_str : String? = nil
      found_table : CQL::Table? = nil

      @query_tables.each do |current_alias_str, info|
        if column = find_column_in_table(info[:table], column_name_str)
          if found_column
            raise ArgumentError.new "Column '#{column_name_str}' is ambiguous between '#{found_in_alias_str}' and '#{current_alias_str}'. Qualify with table alias (e.g., #{current_alias_str}.#{column_name_str})."
          end
          found_column = column
          found_in_alias_str = current_alias_str
          found_table = info[:table]
        end
      end
      raise ArgumentError.new "Column '#{column_name_str}' not found in any tables/aliases: #{@query_tables.keys.join(", ")}" unless found_column
      found_column.not_nil!.tap(&.table=(found_table))
    end
  end

  # Helper to find column in table using String comparison
  # Returns a *copy* of the BaseColumn found, or nil. Does NOT set the table.
  private def find_column_in_table(table : CQL::Table, column_name_str : String) : CQL::BaseColumn?
    table.columns.each_value do |col|
      return col.dup if col.name.to_s == column_name_str
    end
    pk = table.primary
    return pk.dup if pk && pk.name.to_s == column_name_str && !table.columns.has_key?(pk.name)
    nil
  end

  # --- Helper methods for inferred joins (Using String aliases internally) --- #

  # Accepts an Enumerable of {TableNameSym, AliasNameSym} pairs
  private def join_inferred(tables_with_aliases : Enumerable({Symbol, Symbol}), type : Expression::JoinType)
    tables_with_aliases.each do |target_table_name_sym, target_alias_sym|
      unless target_alias_sym.is_a?(Symbol)
        raise ArgumentError.new("Internal Error: Invalid alias type for table '#{target_table_name_sym}'. Expected Symbol, got #{target_alias_sym.class}")
      end

      target_table = find_schema_table(target_table_name_sym)
      final_alias_str = determine_alias(target_table_name_sym, target_alias_sym)
      ensure_alias_available(final_alias_str)

      @query_tables[final_alias_str] = {table: target_table, alias: final_alias_str}

      found_fk = find_foreign_key_link(target_table)
      left_alias_str, left_columns_sym, right_alias_str, right_columns_sym = determine_join_sides(found_fk, final_alias_str)
      on_condition = build_join_condition(left_alias_str, left_columns_sym, right_alias_str, right_columns_sym)
      add_join_expression(target_table, final_alias_str, type, on_condition)
    end
    self
  end

  # Returns String aliases
  private def determine_join_sides(fk : ForeignKey, target_alias_str : String)
    fk_owning_table = fk.table
    fk_referenced_table_name_sym = fk.references_table

    owning_alias_str : String? = find_alias_for_table?(fk_owning_table)
    referenced_alias_str : String? = find_alias_for_table_name?(fk_referenced_table_name_sym)

    left_table_alias_str, right_table_alias_str = if owning_alias_str && !referenced_alias_str
                                                    {owning_alias_str, target_alias_str}
                                                  elsif !owning_alias_str && referenced_alias_str
                                                    {target_alias_str, referenced_alias_str}
                                                  else
                                                    raise "Internal Error: Could not determine join sides. Owning alias: #{owning_alias_str}, Referenced alias: #{referenced_alias_str}, Target alias: #{target_alias_str}"
                                                  end

    left_columns_sym, right_columns_sym = if left_table_alias_str == owning_alias_str || left_table_alias_str == target_alias_str && find_table_by_alias(left_table_alias_str) == fk_owning_table
                                            {fk.columns, fk.references_columns}
                                          else
                                            {fk.references_columns, fk.columns}
                                          end

    {left_table_alias_str, left_columns_sym, right_table_alias_str, right_columns_sym}
  end

  # Finds the String alias for a given Table object, raises KeyError if not found.
  private def find_alias_for_table(table_to_find : CQL::Table) : String
    find_alias_for_table?(table_to_find) || raise KeyError.new("Internal Error: Could not find String alias for table '#{table_to_find.table_name}' in query_tables: #{@query_tables.keys}")
  end

  # Finds the String alias for a given Table object, returns nil if not found.
  private def find_alias_for_table?(table_to_find : CQL::Table) : String?
    @query_tables.each do |alias_str, info|
      return alias_str if info[:table].object_id == table_to_find.object_id
    end
    nil
  end

  # Finds the String alias for a given table name (Symbol), returns nil if not found.
  private def find_alias_for_table_name?(table_name_to_find : Symbol) : String?
    @query_tables.each do |alias_str, info|
      return alias_str if info[:table].table_name == table_name_to_find
    end
    nil
  end

  # Finds the Table object for a given String alias.
  private def find_table_by_alias(alias_str : String) : CQL::Table
    @query_tables[alias_str][:table]
  end

  # Takes String aliases and Symbol column names, creates Expression::Column with String alias
  private def build_join_condition(left_alias_str : String, left_columns_sym : Array(Symbol), right_alias_str : String, right_columns_sym : Array(Symbol))
    unless left_columns_sym.size == right_columns_sym.size
      raise "Internal Error: Mismatched column count in inferred join condition (#{left_columns_sym.size} vs #{right_columns_sym.size}) for aliases '#{left_alias_str}' and '#{right_alias_str}'"
    end

    conditions = left_columns_sym.zip(right_columns_sym).map do |left_col_sym, right_col_sym|
      left_base_col = find_column(left_col_sym, left_alias_str)
      right_base_col = find_column(right_col_sym, right_alias_str)

      Expression::CompareCondition.new(
        Expression::Column.new(left_base_col, alias_name: left_alias_str),
        "=",
        Expression::Column.new(right_base_col, alias_name: right_alias_str)
      )
    end

    conditions.reduce do |acc, cond|
      Expression::And.new(acc, cond)
    end || raise "Internal Error: No conditions generated for join between '#{left_alias_str}' and '#{right_alias_str}'" # Should have at least one condition
  end

  # --- Helper methods for explicit joins (Using String aliases internally) --- #

  # Handles Symbol | Hash input, converts to String alias internally for block version
  private def join_explicitly(table_or_alias : Symbol | Hash(Symbol, Symbol), type : Expression::JoinType, &)
    target_table_name_sym, target_alias_sym = parse_table_or_alias(table_or_alias) # Returns {Symbol, Symbol?}
    join_table_obj = find_schema_table(target_table_name_sym)
    final_alias_str = determine_alias(target_table_name_sym, target_alias_sym) # Returns String
    ensure_alias_available(final_alias_str)                                    # Expects String

    # Add table to query_tables with String alias BEFORE building condition
    @query_tables[final_alias_str] = {table: join_table_obj, alias: final_alias_str}

    # FilterBuilder expects String-keyed hash
    builder = Expression::FilterBuilder.new(@query_tables)

    # Capture the ConditionBuilder returned by the block
    # The block is responsible for creating the condition using the builder
    condition_builder = yield builder

    # Get the condition from the returned builder
    condition = condition_builder.as(Expression::ConditionBuilder).condition

    # add_join_expression expects String alias
    add_join_expression(join_table_obj, final_alias_str, type, condition)

    self
  end

  # Handles Symbol | Hash input, converts to String alias internally for hash version
  private def join_explicitly(table_or_alias : Symbol | Hash(Symbol, Symbol), on : Hash(CQL::BaseColumn, CQL::BaseColumn | DB::Any), type : Expression::JoinType)
    target_table_name_sym, target_alias_sym = parse_table_or_alias(table_or_alias) # Returns {Symbol, Symbol?}
    join_table_obj = find_schema_table(target_table_name_sym)
    final_alias_str = determine_alias(target_table_name_sym, target_alias_sym) # Returns String
    ensure_alias_available(final_alias_str)                                    # Expects String

    # Add table temporarily with String alias for condition building
    # This is needed so find_alias_for_table works within build_explicit_join_condition
    @query_tables[final_alias_str] = {table: join_table_obj, alias: final_alias_str}

    begin
      # Build condition using String aliases
      condition = build_explicit_join_condition(on) # Returns Condition with String aliases

      # add_join_expression expects String alias
      add_join_expression(join_table_obj, final_alias_str, type, condition)
      self
    ensure
      # IMPORTANT: Remove the temporary table entry ONLY IF the join wasn't successfully added.
      # We need the joined table to remain in @query_tables for subsequent selects, wheres etc.
      unless @joins.any? { |j| j.table.alias_name == final_alias_str }
        @query_tables.delete(final_alias_str) if final_alias_str # Check if alias was determined
      end
    end
  end

  # Builds explicit join condition using String aliases internally
  private def build_explicit_join_condition(on : Hash(CQL::BaseColumn, CQL::BaseColumn | DB::Any))
    conditions = on.map do |left_col_def, right_val_or_col_def|
      left_table = left_col_def.table || raise "Internal Error: Left BaseColumn in join condition lacks table information."
      left_alias_str = find_alias_for_table(left_table)

      right_expr = case right_val_or_col_def
                   when CQL::BaseColumn
                     right_table = right_val_or_col_def.table || raise "Internal Error: Right BaseColumn in join condition lacks table information."
                     right_alias_str = find_alias_for_table(right_table)
                     Expression::Column.new(right_val_or_col_def, alias_name: right_alias_str)
                   when DB::Any
                     left_col_def.validate!(right_val_or_col_def)
                     right_val_or_col_def
                   else
                     raise "Invalid type in join condition value: #{right_val_or_col_def.class}"
                   end

      Expression::CompareCondition.new(
        Expression::Column.new(left_col_def, alias_name: left_alias_str),
        "=",
        right_expr
      )
    end

    conditions.reduce do |acc, cond|
      Expression::And.new(acc, cond)
    end || raise "Internal Error: No conditions generated for explicit join" # Should have at least one condition
  end

  # --- General Helper Methods (Using String Aliases) --- #

  # Parses Symbol | Hash input, returns {Symbol<TableName>, Symbol?<AliasName>}
  # Conversion to String alias happens in caller (`determine_alias`)
  private def parse_table_or_alias(item : Symbol | Hash(Symbol, Symbol)) : {Symbol, Symbol?}
    case item
    when Symbol
      {item, nil}
    when Hash(Symbol, Symbol)
      if item.size != 1
        raise ArgumentError.new("Alias mapping must contain exactly one entry, got #{item}")
      end
      name, al = item.first
      {name, al}
    else
      raise ArgumentError.new("Invalid argument type for table/alias: #{item.class}")
    end
  end

  # Determines the String alias to use, converting Symbols using .to_s
  private def determine_alias(table_name_sym : Symbol, suggested_alias_sym : Symbol?) : String
    (suggested_alias_sym || table_name_sym).to_s
  end

  # Expects String alias
  private def ensure_alias_available(alias_to_check : String)
    if @query_tables.has_key?(alias_to_check)
      raise ArgumentError.new "Duplicate alias or table name '#{alias_to_check}' detected in join or from clause."
    end
  end

  # Expects String alias_name
  private def add_join_expression(table : Table, alias_name_str : String, type : Expression::JoinType, condition : Expression::Condition)
    join_table_expr = Expression::Table.new(table, alias_name_str)
    @joins << Expression::Join.new(type, join_table_expr, condition)
    @query_tables[alias_name_str] = {table: table, alias: alias_name_str} unless @query_tables.has_key?(alias_name_str)
  end

  # This seems okay, it deals with schema relationships (Symbols)
  private def find_foreign_key_link(target_table : Table) : ForeignKey
    possible_links = [] of ForeignKey
    existing_aliases_str = @query_tables.keys - [find_alias_for_table(target_table)]

    existing_aliases_str.each do |existing_alias|
      existing_info = @query_tables[existing_alias]
      existing_table = existing_info[:table]

      existing_table.foreign_keys.each do |foreign_key|
        if foreign_key.references_table == target_table.table_name
          possible_links << foreign_key
        end
      end
      target_table.foreign_keys.each do |foreign_key|
        if foreign_key.references_table == existing_table.table_name
          possible_links << foreign_key
        end
      end
    end

    possible_links.uniq!(&.object_id)

    case possible_links.size
    when 0
      raise ArgumentError.new "Could not find a foreign key relationship between '#{target_table.table_name}' and existing tables/aliases [#{existing_aliases_str.join(", ")}]"
    when 1
      possible_links.first
    else
      link_descriptions = possible_links.map do |foreign_key|
        "'#{foreign_key.table.table_name}' (#{foreign_key.columns.join(", ")}) -> '#{foreign_key.references_table}' (#{foreign_key.references_columns.join(", ")})"
      end.join("; ")
      raise ArgumentError.new "Ambiguous relationship found for '#{target_table.table_name}' with existing tables/aliases [#{existing_aliases_str.join(", ")}]. Possible links: #{link_descriptions}. Specify join condition explicitly."
    end
  end
end
