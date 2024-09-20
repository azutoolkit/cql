module Expression
  class FilterBuilder
    @tables : Hash(Symbol, Table) = {} of Symbol => Table

    def initialize(sql_tables : Hash(Symbol, Cql::Table))
      sql_tables.each do |name, table|
        @tables[name] = Table.new(table)
      end
    end

    def exists?(sub_query : Cql::Query)
      ConditionBuilder.new(Exists.new(sub_query.build))
    end

    # Generate methods for each column
    macro method_missing(call)
      def {{call.name.id}}
        @tables[:{{call.name.id}}]
      end
    end
  end
end
