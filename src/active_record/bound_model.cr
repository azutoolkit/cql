require "yaml"

module CQL::ActiveRecord
  # An explicit model receiver. Query methods execute on its binding; arbitrary
  # application class methods are intentionally not delegated.
  class BoundModel(T)
    getter binding : CQL::Binding?

    def initialize(@binding : CQL::Binding? = nil)
    end

    def schema : CQL::Schema
      @binding.try(&.schema(T.schema)) || T.schema
    end

    def table
      T.table
    end

    def primary_key_column
      T.primary_key_column
    end

    def adapter
      schema.adapter
    end

    def query
      original = T.query
      @binding ? original.rebind(schema) : original
    end

    def with_deleted
      T.with_deleted.rebind(schema)
    end

    def only_deleted
      T.only_deleted.rebind(schema)
    end

    def where(&)
      columns = T.cql_columns
      condition = with columns yield columns
      query.where { condition }
    end

    def having(&)
      columns = T.cql_columns
      condition = with columns yield columns
      query.having { condition }
    end

    def order_by(&)
      columns = T.cql_columns
      value = with columns yield columns
      query.order_by { value }
    end

    def find?(id)
      query.find(id)
    end

    def build(**fields) : T
      T.build(**fields).with_binding(@binding)
    end

    def create!(attributes : Hash(Symbol, DB::Any)) : T
      T.create!(attributes, self).with_binding(@binding)
    end

    def create!(**fields) : T
      create!(fields.to_h.transform_values(&.as(DB::Any)))
    end

    def create!(record : T) : T
      T.create!(record.with_binding(@binding))
    end

    def find_or_create_by(fields : Hash(Symbol, DB::Any)) : T
      query.where(fields).first || create!(fields)
    end

    def find_or_create_by(**fields) : T
      query.where(**fields).first || create!(**fields)
    end

    def insert
      CQL::Insert.new(schema).into(table)
    end

    def update
      CQL::Update.new(schema).table(table)
    end

    def delete
      CQL::Delete.new(schema).from(table)
    end

    def update_of(id)
      update.where({primary_key_column => IdChunks.bound(id)})
    end

    def delete_of(id)
      delete.where({primary_key_column => IdChunks.bound(id)})
    end

    def update_row!(id, & : CQL::Update -> CQL::Update)
      result = (yield update_of(id)).commit
      return result if result.rows_affected > 0
      rows = CQL::ActiveRecord::Queryable::QueryBuilder(T).from_model(T).rebind(schema).where_primary_key(id)
      rows = rows.with_query(&.lock) if schema.dialect.supports_row_locks?
      return result if rows.exists?
      raise CQL::RecordNotFound.new("#{T}: the UPDATE matched no row")
    end

    def update!(record : T)
      T.update!(record.with_binding(@binding))
    end

    def update_with_lock!(record : T)
      T.update_with_lock!(record.with_binding(@binding))
    end

    def update!(id, attributes : Hash(Symbol, DB::Any))
      T.update!(id, attributes, self)
    end

    def update!(id, **fields)
      update!(id, fields.to_h.transform_values(&.as(DB::Any)))
    end

    def update_by(where_attrs, update_attrs)
      attributes = update_attrs.dup
      attributes.delete(primary_key_column)
      update.set(attributes).where(where_attrs).commit
    end

    def update_all(attrs)
      update.set(attrs).commit
    end

    def delete!(id)
      {% if T.has_method?(:deleted?) %}
        record = with_deleted.find(id)
        record ? record.delete! : false
      {% else %}
        delete_of(id).commit
      {% end %}
    end

    def force_delete!(id)
      delete_of(id).commit
    end

    def delete_by!(**fields)
      {% if T.has_method?(:deleted?) %}
        affected = 0_i64
        schema.transaction do
          with_deleted.where(**fields).all.each { |record| affected += 1 if record.delete! }
        end
        DB::ExecResult.new(rows_affected: affected, last_insert_id: 0_i64)
      {% else %}
        delete.where(**fields).commit
      {% end %}
    end

    def force_delete_by!(**fields)
      delete.where(**fields).commit
    end

    def force_delete_all
      delete.commit
    end

    def restore!(id) : Bool
      record = with_deleted.find(id)
      record && record.deleted? ? record.restore! : false
    end

    def restore_all : Int64
      total = 0_i64
      IdChunks.each(only_deleted.ids(as: T.stored_id_type), adapter.dialect.max_bind_params - 1) do |chunk|
        key = schema.tables[table].columns[primary_key_column].expression
        total += update.set(deleted_at: nil).where { key.in(chunk) }.commit.rows_affected
      end
      total
    end

    def count_with_deleted(column : Symbol = :*)
      with_deleted.count(column)
    end

    def count_only_deleted(column : Symbol = :*)
      only_deleted.count(column)
    end

    def delete_ids(ids : Array) : Int64
      total = 0_i64
      IdChunks.each(ids, adapter.dialect.max_bind_params - 1) do |chunk|
        key = schema.tables[table].columns[primary_key_column].expression
        {% if T.has_method?(:deleted?) %}
          total += update.set(deleted_at: Time.utc).where(deleted_at: nil).where { key.in(chunk) }.commit.rows_affected
        {% else %}
          total += delete.where { key.in(chunk) }.commit.rows_affected
        {% end %}
      end
      total
    end

    def delete_all
      query.delete_all
    end

    def insert_all(rows : Array, batch_size : Int32? = nil)
      bulk(rows).call(batch_size)
    end

    def upsert_all(rows : Array, on_conflict : Symbol | Array(Symbol), update : Array(Symbol)? = nil, batch_size : Int32? = nil)
      target = on_conflict.is_a?(Symbol) ? [on_conflict] : on_conflict
      bulk(rows, BulkInsert::Conflict.new(target, update)).call(batch_size)
    end

    private def bulk(rows, conflict : BulkInsert::Conflict? = nil)
      generate_id = {% if T.constant(:CQL_PRIMARY_KEY_TYPE).resolve == UUID %}
                      -> { UUID.random.to_s.as(DB::Any) }
                    {% elsif T.constant(:CQL_PRIMARY_KEY_TYPE).resolve == String %}
                      -> { CQL::ULIDCompat.generate.as(DB::Any) }
                    {% else %}
                      nil
                    {% end %}
      values = rows.map { |row| row.to_h.transform_values(&.as(DB::Any)) }
      BulkInsert.new(schema, table, values, generate_id, conflict, primary_key_column)
    end

    def touch_all(ids : Array, *fields, time : Time = Time.utc) : Int64
      return 0_i64 if ids.empty?
      names = fields.empty? ? [:updated_at] : fields.to_a
      attrs = {} of Symbol => DB::Any
      names.each do |name|
        raise CQL::Error.new("Unknown column: #{name}") unless schema.tables[table].columns.has_key?(name)
        attrs[name] = time
      end
      total = 0_i64
      IdChunks.each(ids, adapter.dialect.max_bind_params - attrs.size) do |chunk|
        key = schema.tables[table].columns[primary_key_column].expression
        total += update.set(attrs).where { key.in(chunk) }.commit.rows_affected
      end
      total
    end

    def transaction(**options, &)
      schema.transaction(**options) { |tx| yield tx }
    end

    macro method_missing(call)
      query.{{call}}
    end
  end

  module Bindable
    macro included
      @[DB::Field(ignore: true)]
      @[JSON::Field(ignore: true)]
      @[YAML::Field(ignore: true)]
      getter binding : CQL::Binding? = nil

      def with_binding(value : CQL::Binding?) : self
        if previous = @binding
          if value.nil? || !previous.same?(value)
            raise CQL::Error.new("Cannot attach a record to a different binding")
          end
        end
        @binding = value
        self
      end

      # :nodoc:
      def persistence_model
        CQL::ActiveRecord::BoundModel({{@type}}).new(@binding)
      end

      # :nodoc:
      def persistence_schema : CQL::Schema
        persistence_model.schema
      end

      # :nodoc: Preload batches must belong to a single execution context.
      def self.preload_binding(records : Array(self)) : CQL::Binding?
        binding = records.first?.try(&.binding)
        unless records.all? { |record| record.binding == binding }
          raise CQL::Error.new("Cannot preload records from different bindings")
        end
        binding
      end

      def self.on(target : DB::Database | DB::Connection | DB::Transaction)
        on(CQL::Binding.new(target))
      end

      def self.on(binding : CQL::Binding?)
        CQL::ActiveRecord::BoundModel({{@type}}).new(binding)
      end

      def self.insert(target)
        on(target).insert
      end

      def self.update(target)
        on(target).update
      end

      def self.delete(target)
        on(target).delete
      end
    end
  end
end
