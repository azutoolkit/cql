module CQL
  module ActiveRecord
    class Query(Target) < CQL::Query
      @model_class : Target.class
      @eager_loaded_associations : Array(Symbol) = [] of Symbol

      def initialize(schema : CQL::Schema)
        super(schema)
        @model_class = Target
        @eager_loaded_associations = [] of Symbol
      end

      protected def spawn_with(new_query : ::CQL::Query)
        query = self.class.new(self.schema).merge(new_query)
        @eager_loaded_associations = @eager_loaded_associations.dup
        query
      end

      # Eager load associations to prevent N+1 queries
      # - **@param** associations [Array(Symbol)] The associations to eager load
      # - **@return** [Query(Target)] A new query with eager loading configured
      #
      # **Example**
      # ```
      # User.includes(:posts, :comments).all
      # ```
      def includes(*associations : Symbol)
        spawn_with(self)
        @eager_loaded_associations = @eager_loaded_associations + associations.to_a
        self
      end

      # Override all to handle eager loading
      def all
        records = super(@model_class)
        return records if @eager_loaded_associations.empty?

        # Load associations for all records
        @eager_loaded_associations.each do |association|
          load_association(records, association)
        end

        records
      end

      macro create_scope_method(name_ident, scope_proc_code)
        def {{name_ident.id}}(*args)
          # `self` here is an instance of ::CQL::Query(CURRENT_MODEL_CLASS).
          # `self.query` should be the current accumulated CQL::Query.
          # `self.model_class` should be CURRENT_MODEL_CLASS.

          # Execute the scope_proc_code. `self` inside the proc is CURRENT_MODEL_CLASS.
          # This will typically return a Query(CURRENT_MODEL_CLASS) or a raw CQL::Query.
          scope_logic_result = ({{scope_proc_code}}).call(*args)

          cql_query_fragment_for_scope : ::CQL::Query
          if scope_logic_result.is_a?(::CQL::Query)
            cql_query_fragment_for_scope = scope_logic_result
          elsif scope_logic_result.is_a?(Query({{@type.id}}))
            # Assumes Query has a `query` getter for its underlying CQL::Query.
            cql_query_fragment_for_scope = scope_logic_result.query
          else
            raise "Scope '{{name_ident.id}}' for model #{CURRENT_MODEL_CLASS}, when applied in a chain, " \
                  "did not produce a compatible CQL::Query or Query(#{{{@type.id}}}). " \
                  "Received: #{scope_logic_result.class}"
          end

          # Merge the new scope's CQL query fragment into the existing query of this Query instance.
          # Assumes `self.query.merge(...)` returns a new, merged CQL::Query instance.
          current_underlying_query = self.query # Assumes .query getter
          new_underlying_query = current_underlying_query.merge(cql_query_fragment_for_scope)

          # Return a new Query instance with the merged query, promoting immutability.
          # Assumes Query(ModelType).new(cql_query) constructor.
          Query({{@type.id}}).new(new_underlying_query)
        end
      end

      private def load_association(records : Array(Target), association : Symbol)
        return if records.empty?

        # Get the association definition from the model
        association_def = Target.association(association)
        return unless association_def

        case association_def.type
        when :has_many, :has_and_belongs_to_many
          load_has_many_association(records, association_def)
        when :belongs_to
          load_belongs_to_association(records, association_def)
        when :has_one
          load_has_one_association(records, association_def)
        end
      end

      private def load_has_many_association(records : Array(Target), association_def)
        # Get the foreign key and target model
        foreign_key = association_def.foreign_key
        target_model = association_def.target_model

        # Get all IDs from the records
        ids = records.map(&.id)

        # Query the associated records
        associated_records = target_model.query
          .where { target_model.schema_table.columns[foreign_key] == ids }
          .all

        # Group associated records by foreign key
        grouped_records = associated_records.group_by(foreign_key)

        # Set the association on each record
        records.each do |record|
          # Use a macro to generate the setter method call
          {% begin %}
            record.{{association_def.name.id}} = grouped_records[record.id]? || [] of target_model
          {% end %}
        end
      end

      private def load_belongs_to_association(records : Array(Target), association_def)
        # Get the foreign key and target model
        foreign_key = association_def.foreign_key
        target_model = association_def.target_model

        # Get all foreign keys from the records
        foreign_keys = records.map(&.send(foreign_key)).compact.uniq

        return if foreign_keys.empty?

        # Query the associated records
        associated_records = target_model
          .query
          .where { target_model.schema_table.columns[:id] == foreign_keys }
          .all
          .index_by(&.id)

        # Set the association on each record
        records.each do |record|
          if foreign_key_value = record.primary_key
            # Use a macro to generate the setter method call
            {% begin %}
              record.{{association_def.name.id}} = associated_records[foreign_key_value]?
            {% end %}
          end
        end
      end

      private def load_has_one_association(records : Array(Target), association_def)
        # Get the foreign key and target model
        foreign_key = association_def.foreign_key
        target_model = association_def.target_model

        # Get all IDs from the records
        ids = records.map(&.id)

        # Query the associated records
        associated_records = target_model
          .query
          .where { target_model.schema_table.columns[foreign_key] == ids }
          .all
          .index_by(foreign_key)
        # Set the association on each record
        records.each do |record|
          # Use a macro to generate the setter method call
          {% begin %}
            record.{{association_def.name.id}} = associated_records[record.primary_key]?
          {% end %}
        end
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
        super(**fields)
        spawn_with(self)
      end

      def where(&block)
        super(&block)
        spawn_with(self)
      end

      def order(**fields)
        super(**fields)
        spawn_with(self)
      end

      def limit(limit : Int32)
        super(limit)
        spawn_with(self)
      end

      def offset(offset : Int32)
        super(offset)
        spawn_with(self)
      end

      def select(*fields)
        super(*fields)
        spawn_with(self)
      end

      def group_by(*fields)
        super(*fields)
        spawn_with(self)
      end

      def join(table : Symbol, on)
        on_hash = on.is_a?(Hash) ? on : on.to_h
        super(table, on_hash)
        spawn_with(self)
      end

      def minimum(field : Symbol)
        super(field)
        spawn_with(self)
      end

      def maximum(field : Symbol)
        super(field)
        spawn_with(self)
      end

      def sum(field : Symbol)
        super(field)
        spawn_with(self)
      end

      def average(field : Symbol)
        super(field)
        spawn_with(self)
      end

      def group(*fields)
        super(*fields)
        spawn_with(self)
      end

      def having(condition : String, *args)
        super(condition, *args)
        spawn_with(self)
      end

      def having(&block)
        super(&block)
        spawn_with(self)
      end

      def inner(table_or_alias : Symbol | Hash(Symbol, Symbol), &block)
        super(table_or_alias, &block)
        spawn_with(self)
      end

      def left(table_or_alias : Symbol | Hash(Symbol, Symbol), &block)
        super(table_or_alias, &block)
        spawn_with(self)
      end

      def right(table_or_alias : Symbol | Hash(Symbol, Symbol), &block)
        super(table_or_alias, &block)
        spawn_with(self)
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
