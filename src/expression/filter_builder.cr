require "./expressions"

module Expression
  class FilterBuilder
    @tables : Hash(String, Expression::Table) = {} of String => Expression::Table

    def initialize(query_tables : Hash(String, CQL::Query::QueryTableInfo))
      query_tables.each do |alias_str, table_info|
        @tables[alias_str] = Expression::Table.new(table_info[:table], alias_str)
      end
    end

    def exists?(sub_query : CQL::Query)
      ConditionBuilder.new(Exists.new(sub_query.build))
    end

    # Direct table access method
    def table(name : String)
      @tables[name]? || raise "Table '#{name}' not found in filter context. Available tables: #{@tables.keys.join(", ")}"
    end

    def table(name : Symbol)
      table(name.to_s)
    end

    # Generate methods for each table using method_missing
    macro method_missing(call)
      def {{call.name.id}}
        table_name = {{call.name.stringify}}
        table = @tables[table_name]?
        unless table
          raise "Table '#{table_name}' not found in filter context. Available tables: #{@tables.keys.join(", ")}"
        end
        table
      end
    end
  end
end
