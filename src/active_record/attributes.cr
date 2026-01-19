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
            # Check for DB::Field key annotation to map internal storage to DB column name
            {% db_field = ivar.annotation(DB::Field) %}
            {% key_name = db_field && db_field.named_args[:key] ? db_field.named_args[:key].id : ivar.id %}
            {% if is_uuid %}
              # Convert UUID to String for DB::Any compatibility
              _val = @{{ ivar.id }}
              hash[:{{ key_name }}] = _val.nil? ? nil : _val.to_s
            {% else %}
              hash[:{{ key_name }}] = @{{ ivar.id }}
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
        attrs.each do |key, value|
          {% for ivar in @type.instance_vars %}
            if key == :{{ivar.id}}
              {% if ivar.type.resolve.nilable? %}
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
        attrs.each do |key, value|
          {% for ivar in @type.instance_vars %}
            if key == :{{ivar.id}}
              {% if ivar.type.resolve.nilable? %}
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
      end
    end
  end
end
