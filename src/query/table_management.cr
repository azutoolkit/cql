# Handles methods related to the FROM clause and table management.
module TableManagement
  # Specifies the tables to select from using splat arguments.
  def from(*tbls_or_aliases : Symbol | Hash(Symbol, Symbol))
    clear_query_state_for_new_from
    tbls_or_aliases.each do |item|
      add_table_or_alias(item)
    end
    self
  end

  # Specifies tables to select from using keyword arguments for aliases.
  def from(**tables_with_aliases)
    clear_query_state_for_new_from
    tables_with_aliases.each do |table_name_sym, table_alias_sym|
      # Ensure alias is a Symbol (as expected from **)
      unless table_alias_sym.is_a?(Symbol)
        raise ArgumentError.new("Invalid alias type for table '#{table_name_sym}'. Expected Symbol, got #{table_alias_sym.class}")
      end
      add_table_or_alias({table_name_sym, table_alias_sym})
    end
    self
  end

  private def clear_query_state_for_new_from
    @query_tables.clear # FROM clause resets tables
    @columns.clear      # Also clear selected columns when FROM changes
    @joins.clear        # Clear joins as well
    @aggr_columns.clear # Clear aggregates
  end

  private def add_table_or_alias(item : Symbol | Hash(Symbol, Symbol))
    table_name_sym, table_alias_sym = parse_table_or_alias(item) # Returns {Symbol, Symbol?}
    table = find_schema_table(table_name_sym)
    table_alias_str = determine_alias(table_name_sym, table_alias_sym)      # Returns String
    ensure_alias_available(table_alias_str)                                 # Expects String
    @query_tables[table_alias_str] = {table: table, alias: table_alias_str} # Store with String alias
  end
end
