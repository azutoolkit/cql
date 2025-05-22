module CQL
  module ActiveRecord
    class Query(Target) < ::CQL::Query
      @model_class : Target.class

      def initialize(schema : CQL::Schema)
        super(schema)
        @model_class = Target
      end

      protected def spawn_with(new_query : ::CQL::Query)
        self.class.new(self.schema).merge(new_query)
      end

      # Execute the query and return all matching records
      def all
        super(@model_class)
      end

      # Execute the query and return the first matching record, or nil if none found
      def first
        super(@model_class)
      rescue DB::NoResultsError
        nil
      end

      # Execute the query and return the first matching record, raising if none found
      def first!
        super(@model_class)
      end

      # Count the number of matching records
      def count
        self.count(:id).first!(Int64)
      end

      # Add a where clause to the query
      def where(**fields)
        spawn_with(super(**fields))
      end

      def where(&block)
        spawn_with(super(&block))
      end

      def order(**fields)
        spawn_with(super(**fields))
      end

      def limit(limit : Int32)
        spawn_with(super(limit))
      end

      def offset(offset : Int32)
        spawn_with(super(offset))
      end

      def select(*fields)
        spawn_with(super(*fields))
      end

      def group_by(*fields)
        spawn_with(super(*fields))
      end

      def join(table : Symbol, on)
        on_hash = on.is_a?(Hash) ? on : on.to_h
        spawn_with(super(table, on_hash))
      end

      def minimum(field : Symbol)
        self.min(field).first
      end

      def maximum(field : Symbol)
        self.max(field).first
      end

      def sum(field : Symbol)
        self.sum(field).first
      end

      def average(field : Symbol)
        self.avg(field).first
      end

      def group(*fields)
        spawn_with(super(*fields))
      end

      def having(condition : String, *args)
        spawn_with(super(condition, *args))
      end

      def having(&block)
        spawn_with(super(&block))
      end

      def inner(table_or_alias : Symbol | Hash(Symbol, Symbol), &block)
        spawn_with(super(table_or_alias, &block))
      end

      def left(table_or_alias : Symbol | Hash(Symbol, Symbol), &block)
        spawn_with(super(table_or_alias, &block))
      end

      def right(table_or_alias : Symbol | Hash(Symbol, Symbol), &block)
        spawn_with(super(table_or_alias, &block))
      end

      # Returns all primary keys as an array of Pk
      def ids : Array(Pk)
        self.select(:id).pluck(:id).map(&.as(Pk))
      end

      # Pluck one or more columns as an array
      def pluck(*fields)
        super(*fields).map do |row|
          # If only one field, flatten
          if fields.size == 1 && row.is_a?(Array)
            row[0]
          else
            row
          end
        end
      end

      # Pick the value(s) from the first row for the given columns
      def pick(*fields)
        result = super(*fields)
        if fields.size == 1 && result.is_a?(Array)
          result[0]
        else
          result
        end
      end

      # Returns true if any record exists for the query
      def exists?(**fields)
        self.where(**fields).limit(1).first != nil
      end

      # Take n records or the first record if n is nil
      def take(n : Int32? = nil)
        q = n ? self.limit(n) : self
        n ? q.all : q.first
      rescue DB::NoResultsError
        n ? [] of Target : nil
      end

      # Take n records or the first record if n is nil, raise if not found
      def take!(n : Int32? = nil)
        q = n ? self.limit(n) : self
        n ? q.all : q.first!
      end

      # Find the first record matching attributes
      def find_by(**fields)
        self.where(**fields).limit(1).first
      end

      # Find the first record matching attributes, raise if not found
      def find_by!(**fields)
        self.where(**fields).limit(1).first!
      end

      # Find all records matching attributes
      def find_all_by(**fields)
        self.where(**fields).all
      end

      # Alias for first (returns first record or nil)
      def first?
        self.first
      end

      # Returns the last record (order by id desc)
      def last
        self.order(id: :desc).limit(1).first
      end

      # Alias for last (returns last record or nil)
      def last?
        self.last
      end
    end
  end
end
