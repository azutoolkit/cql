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
            hash[:{{ ivar }}] = {{ ivar }}
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
                {% non_nil_type = ivar.type.resolve.union_types.find { |t| t != Nil } %}
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
                {% non_nil_type = ivar.type.resolve.union_types.find { |t| t != Nil } %}
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
