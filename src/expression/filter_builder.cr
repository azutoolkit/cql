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

    # Generate methods for each column
    macro method_missing(call)
      def {{call.name.id}}
        @tables[{{call.name.stringify}}]
      end
    end
  end
end
