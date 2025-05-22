require "./query"

module CQL
  # The MergeQuery class is responsible for merging the properties of one Query object
  # into another. It encapsulates the logic previously found in Query#merge.
  class MergeQuery
    @current_query : CQL::Query
    @other_query : CQL::Query

    # Initializes a new MergeQuery instance.
    # - @param current_query The query to be modified.
    # - @param other_query The query whose properties will be merged into current_query.
    def initialize(@current_query : Query, @other_query : Query)
    end

    # Executes the merge operation, modifying `@current_query` in place.
    # - @return The modified `@current_query` object.
    def execute : Query
      # Schema check remains at the beginning
      unless @current_query.schema.object_id == @other_query.schema.object_id
        raise ArgumentError.new "Cannot merge queries: Schemas are different."
      end

      merge_distinct
      merge_collections
      merge_query_tables
      merge_where_clause
      merge_group_by
      merge_having_clause
      merge_order_by
      merge_limit
      merge_offset

      @current_query
    end

    private def merge_distinct
      # Uses the 'distinct=' setter on Query (to be added via 'property' macro)
      @current_query.distinct = @current_query.distinct? || @other_query.distinct?
    end

    private def merge_collections
      # These directly modify collections obtained via getters. This is okay.
      @current_query.columns.concat(@other_query.columns).uniq!(&.object_id)
      @current_query.aggr_columns.concat(@other_query.aggr_columns).uniq!(&.object_id)
      @current_query.joins.concat(@other_query.joins).uniq!(&.object_id)
    end

    private def merge_query_tables
      # Modifies the hash obtained via getter. This is okay.
      @other_query.query_tables.each do |alias_str, other_info|
        if current_info = @current_query.query_tables[alias_str]?
          if current_info[:table].object_id != other_info[:table].object_id || current_info[:alias] != other_info[:alias]
            raise ArgumentError.new "Merge conflict: Alias '#{alias_str}' in merged query refers to a different table or internal alias string than in the current query. Current table: #{current_info[:table].table_name}, Other table: #{other_info[:table].table_name}"
          end
        else
          @current_query.query_tables[alias_str] = other_info
        end
      end
    end

    private def merge_where_clause
      current_w = @current_query.where
      other_w = @other_query.where

      if current_w && other_w
        # Only merge if both are Expression::Where or Expression::Condition
        if (current_w.is_a?(Expression::Where) || current_w.is_a?(Expression::Condition)) &&
           (other_w.is_a?(Expression::Where) || other_w.is_a?(Expression::Condition))
          current_condition = current_w.is_a?(Expression::Where) ? current_w.condition : current_w.as(Expression::Condition)
          other_condition = other_w.is_a?(Expression::Where) ? other_w.condition : other_w.as(Expression::Condition)
          merged_condition = Expression::And.new(current_condition, other_condition)
          @current_query.where = Expression::Where.new(merged_condition)
        else
          # If not mergeable, only assign if current_w is Expression::Where
          @current_query.where = current_w.is_a?(Expression::Where) ? current_w : nil
        end
      elsif other_w
        @current_query.where = other_w.is_a?(Expression::Where) ? other_w : nil
      end
    end

    private def merge_group_by
      # Only concat if both are Array(CQL::BaseColumn)
      if gb1 = @current_query.group_by.as?(Array(CQL::BaseColumn))
        if gb2 = @other_query.group_by.as?(Array(CQL::BaseColumn))
          gb1.concat(gb2).uniq!(&.object_id)
        end
      end
    end

    private def merge_having_clause
      current_h = @current_query.having
      other_h = @other_query.having

      if current_h
        if other_h
          # Assuming Expression::And and Expression::Having are available
          merged_condition = Expression::And.new(current_h.condition, other_h.condition)
          # Uses the 'having=' setter on Query (to be added via 'property' macro)
          @current_query.having = Expression::Having.new(merged_condition)
        end
      else
        # Uses the 'having=' setter on Query
        @current_query.having = other_h
      end
    end

    private def merge_order_by
      # Modifies the hash obtained via getter. This is okay.
      @other_query.order_by.each do |col, dir|
        @current_query.order_by[col] = dir
      end
    end

    private def merge_limit
      oq_limit = @other_query.limit
      if oq_limit
        cq_limit = @current_query.limit
        if cq_limit
          # Uses the 'limit=' setter on Query (to be added via 'property' macro)
          @current_query.limit = Math.min(cq_limit, oq_limit)
        else
          # Uses the 'limit=' setter on Query
          @current_query.limit = oq_limit
        end
      end
    end

    private def merge_offset
      # Uses the 'offset=' setter on Query (to be added via 'property' macro)
      if oq_offset = @other_query.offset
        @current_query.offset = oq_offset
      end
    end
  end
end
