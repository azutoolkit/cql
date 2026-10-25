module CQL
  module ActiveRecord
    # Opt-in change tracking. A record remembers its column values as last loaded or saved,
    # reports what changed since, and `update!`/`save` send only the changed columns: a
    # column another writer changed meanwhile is left alone, and a record with no changes
    # sends no UPDATE (and keeps its `updated_at`). Callbacks still run.
    #
    # Include it after `CQL::ActiveRecord::Model`:
    #
    # ```
    # class User
    #   include CQL::ActiveRecord::Model(Int64)
    #   include CQL::ActiveRecord::DirtyTracking
    #   db_context schema: AppDB, table: :users
    #
    #   property name : String = ""
    # end
    #
    # user = User.find!(1)
    # user.name = "Ada"
    # user.changes # => {:name => {"Grace", "Ada"}}
    # user.save    # UPDATE users SET name = ?, updated_at = ? WHERE users.id = ?
    # ```
    #
    # Changes are found by comparing values, so assignments through setters, `attributes`
    # and instance variables all count. A record that was never loaded or saved counts
    # every attribute as changed.
    module DirtyTracking
      macro included
        \{% unless @type.has_constant?(:CQL_PRIMARY_KEY_TYPE) %}
          \{% raise "#{@type}: include CQL::ActiveRecord::Model(Pk) before CQL::ActiveRecord::DirtyTracking (included first, Model's save and update! replace its overrides)" %}
        \{% end %}

        @[DB::Field(ignore: true)]
        @persisted_attributes : Hash(Symbol, DB::Any)? = nil

        # `save` found nothing to stamp, so a change a later callback makes is stamped on update.
        @[DB::Field(ignore: true)]
        @stamp_on_update : Bool = false

        def initialize(*, __set_for_db_serializable rs : ::DB::ResultSet)
          super
          clear_changes!
        end

        # Sends only the changed columns, and nothing when no column changed.
        def self.update!(record : {{@type.id}})
          changed = record.changed_columns
          record.stamp_deferred_update(changed)
          unless changed.empty?
            CQL::Update.new({{@type.id}}.schema).table({{@type.id}}.table).set(changed).where(id: record.id!).commit
          end
          record.clear_changes!
          record
        end

        # Clean once inserted, before the after_create/after_save callbacks run, so what they
        # change is still saved by the next `save`.
        def self.create!(record : {{@type.id}}) : {{@type.id}}
          previous_def.tap(&.clear_changes!)
        end

        def reload!
          previous_def.tap { clear_changes! }
        end

        # A record with nothing to save is not stamped, so its UPDATE can be skipped; a callback
        # that then changes it gets its stamp in `update!`.
        private def set_timestamps!
          @stamp_on_update = persisted? && !changed?
          previous_def unless @stamp_on_update
        end

        # :nodoc:
        # Consumes the flag `set_timestamps!` left, stamping `updated_at` into *changed* (and the
        # record) when this `save` found nothing to stamp but its callbacks changed something.
        def stamp_deferred_update(changed : Hash(Symbol, DB::Any)) : Nil
          deferred, @stamp_on_update = @stamp_on_update, false
          return unless deferred
          return if changed.empty? || changed.has_key?(:updated_at) || !has_timestamp_column?(:updated_at)
          stamp = {:updated_at => Time.utc.as(DB::Any)}
          attributes(stamp)
          changed.merge!(stamp)
        end
      end

      # Whether any attribute differs from its last loaded or saved value.
      def changed? : Bool
        original = @persisted_attributes
        return true unless original
        attributes != original
      end

      def attribute_changed?(name : Symbol) : Bool
        original = @persisted_attributes
        return true unless original
        attributes[name]? != original[name]?
      end

      # Each changed attribute with its `{old, new}` values (`old` is nil for a record never
      # loaded or saved).
      def changes : Hash(Symbol, {DB::Any, DB::Any})
        original = @persisted_attributes
        result = {} of Symbol => {DB::Any, DB::Any}
        attributes.each do |name, value|
          old = original.try(&.[name]?)
          result[name] = {old, value} if original.nil? || old != value
        end
        result
      end

      # The changed columns and their new values, as an UPDATE sets them (never the id).
      def changed_columns : Hash(Symbol, DB::Any)
        changes.each_with_object({} of Symbol => DB::Any) do |(name, (_, value)), columns|
          columns[name] = value unless name == :id
        end
      end

      # Takes the current values as the saved ones. Byte slices are copied, so changing one in
      # place still counts as a change.
      def clear_changes! : Nil
        @persisted_attributes = attributes.transform_values { |value| value.is_a?(Bytes) ? value.dup : value }
      end
    end
  end
end
