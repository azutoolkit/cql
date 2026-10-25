module CQL
  module ActiveRecord
    module Attributes
      # Define instance-level methods for querying and manipulating data
      # Fetch the record's ID or raise an error if it's nil
      # - **@return** [PrimaryKey] The ID
      #
      # **Example** Fetching the record's attributes
      #
      # ```
      # user.attributes
      # -> { id: 1, name: "Alice", email: " [email protected]" }
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
      # user.attributes = {name: "Alice", email: "[email protected]"}
      # ```
      def attributes(attrs : Hash(Symbol, DB::Any))
        attrs.each { |key, value| assign_attribute(key, value) }
      end

      # Set the record's attributes from a hash
      # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to set
      # - **@return** [Nil]
      #
      # **Example** Setting the record's attributes
      #
      # ```
      # user.attributes(name: "Alice", email: "[email protected]")
      # ```
      def attributes(**attrs)
        attrs.each { |key, value| assign_attribute(key, value) }
      end

      # Expands to the key an instance variable is read and written under: its `DB::Field` key when
      # it has one, so the primary key storage answers to its column name, else its own name.
      private macro attribute_key(ivar_name)
        {% ivar = @type.instance_vars.find { |var| var.name == ivar_name.id } %}
        {% db_field = ivar.annotation(DB::Field) %}
        :{{ db_field && db_field[:key] ? db_field[:key].id : ivar.name }}
      end

      private def assign_attribute(key : Symbol, value) : Nil
        {% for ivar in @type.instance_vars %}
          if key == attribute_key({{ivar.id}})
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
