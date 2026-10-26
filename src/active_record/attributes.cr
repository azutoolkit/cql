module CQL
  module ActiveRecord
    module Attributes
      # The record's attributes, keyed by column name
      # - **@return** [Hash(Symbol, DB::Any)] The attributes
      #
      # **Example** Fetching the record's attributes
      #
      # ```
      # user.attributes[:name] # => "Alice"
      # ```
      def attributes
        hash = Hash(Symbol, DB::Any).new
        {% for ivar in @type.instance_vars %}
          {% if !ivar.annotation(DB::Field) || !ivar.annotation(DB::Field).named_args[:ignore] %}
            {% ivar_type = ivar.type.resolve %}
            {% is_uuid = ivar_type == UUID || (ivar_type.union? && ivar_type.union_types.any? { |union_type| union_type == UUID }) %}
            {% if is_uuid %}
              # Convert UUID to String for DB::Any compatibility
              _val = @{{ ivar.id }}
              hash[attribute_key({{ ivar.id }})] = _val.nil? ? nil : _val.to_s
            {% else %}
              hash[attribute_key({{ ivar.id }})] = @{{ ivar.id }}
            {% end %}
          {% end %}
        {% end %}
        hash
      end

      # Set the record's attributes from a hash
      # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to set
      # - **@return** [Nil]
      #
      # **Example** Setting the record's attributes
      #
      # ```
      # user.attributes({:name => "Alice", :email => "alice@example.com"} of Symbol => DB::Any)
      # ```
      #
      # The primary key is not assigned: mass assignment must not re-point a record at another row.
      # Set it with `id=`.
      def attributes(attrs : Hash(Symbol, DB::Any))
        attrs.each { |key, value| assign_attribute(key, value, with_primary_key: false) }
      end

      # Set the record's attributes from a hash
      # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to set
      # - **@return** [Nil]
      #
      # **Example** Setting the record's attributes
      #
      # ```
      # user.attributes(name: "Alice", email: "alice@example.com")
      # ```
      #
      # Like `attributes(Hash)`, this never assigns the primary key.
      def attributes(**attrs)
        attrs.each { |key, value| assign_attribute(key, value, with_primary_key: false) }
      end

      # Sets attributes including the primary key, for `from_hash` on trusted data.
      protected def _assign_attributes_with_primary_key(attrs : Hash(Symbol, DB::Any)) : Nil
        attrs.each { |key, value| assign_attribute(key, value, with_primary_key: true) }
      end

      # Expands to the key an instance variable is read and written under: its `DB::Field` key when
      # it has one, so the primary key storage answers to its column name, else its own name.
      private macro attribute_key(ivar_name)
        {% ivar = @type.instance_vars.find { |var| var.name == ivar_name.id } %}
        {% db_field = ivar.annotation(DB::Field) %}
        :{{ db_field && db_field[:key] ? db_field[:key].id : ivar.name }}
      end

      private def assign_attribute(key : Symbol, value, *, with_primary_key : Bool) : Nil
        {% for ivar in @type.instance_vars %}
          {% primary_key_storage = ivar.name.stringify == "id" || ivar.name.stringify == "_id_storage" %}
          if key == attribute_key({{ivar.id}}){% if primary_key_storage %} && with_primary_key{% end %}
            {% if ivar.name.stringify == "_id_storage" %}
              # A UUID key is stored as text, so only a well-formed UUID may reach it
              if value.is_a?(String) && (uuid_text = canonical_uuid?(value))
                @{{ivar.id}} = uuid_text
              end
            {% elsif ivar.type.resolve.nilable? %}
              # Handle nilable types - check if value matches the non-nil type or is nil
              {% non_nil_type = ivar.type.resolve.union_types.find { |kind| kind != Nil } %}
              if value.nil?
                @{{ivar.id}} = nil
              elsif value.is_a?({{non_nil_type}})
                @{{ivar.id}} = value.as({{non_nil_type}})
              end
            {% else %}
              # Handle non-nilable types normally
              if value.is_a?({{ivar.type}})
                @{{ivar.id}} = value
              end
            {% end %}
          end
        {% end %}
      end

      # Uses `UUID.new` because `UUID.parse?` is newer than the oldest Crystal this shard supports.
      private def canonical_uuid?(text : String) : String?
        UUID.new(text).to_s
      rescue ArgumentError
        nil
      end
    end
  end
end
