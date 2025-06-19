module CQL::ActiveRecord::Relations
  # Base module providing common functionality for all relation types
  # This module establishes consistent patterns for error handling,
  # type safety, and shared behaviors across different association types.
  module BaseRelation
    # Common exception types for relation operations
    class RelationError < Exception; end
    class AssociationNotFound < RelationError; end
    class InvalidAssociation < RelationError; end
    class UnsavedRecord < RelationError; end

    # Safely retrieves the primary key, raising appropriate error if nil
    # - **param** : record (T) - The record to get ID from
    # - **return** : Pk - The primary key value
    # - **raise** : UnsavedRecord if record has no ID
    macro safe_id(record, pk_type)
      %id = {{record}}.id
      raise UnsavedRecord.new("Cannot operate on unsaved record") if %id.nil?
      %id.as({{pk_type}})
    end

    # Safely retrieves a foreign key value with proper error handling
    # - **param** : record (T) - The record to get foreign key from
    # - **param** : key (Symbol) - The foreign key field name
    # - **return** : Pk - The foreign key value
    # - **raise** : InvalidAssociation if foreign key is nil
    macro safe_foreign_key(record, key, pk_type)
      %fk = {{record}}.{{key.id}}
      raise InvalidAssociation.new("Foreign key {{key.id}} cannot be nil") if %fk.nil?
      %fk.as({{pk_type}})
    end

    # Generates underscore naming for associations
    # - **param** : class_name (String) - The class name to convert
    # - **return** : String - The underscored version
    macro underscore_name(class_name)
      {{class_name}}.gsub(/([A-Z])/, "_\\1").downcase.lstrip('_')
    end

    # Common validation for persisted records
    # - **param** : record (T) - The record to validate
    # - **raise** : UnsavedRecord if record is not persisted
    macro ensure_persisted(record)
      unless {{record}}.persisted?
        raise UnsavedRecord.new("Record must be saved before association operations")
      end
    end

    # Safe database operation wrapper with consistent error handling
    # - **param** : operation (Block) - The database operation to execute
    # - **return** : T - The result of the operation
    # - **raise** : RelationError on database errors
    macro safe_db_operation(&block)
      begin
        {{block.body}}
      rescue ex : DB::Error
        raise RelationError.new("Database operation failed: #{ex.message}")
      rescue ex : CQL::Schema::ConnectionError
        raise RelationError.new("Connection error: #{ex.message}")
      end
    end

    # Creates a query builder with proper error handling
    # - **param** : model_class (Class) - The model class to query
    # - **return** : CQL::Query - A configured query builder
    macro build_query(model_class)
      safe_db_operation do
        CQL::Query.new({{model_class}}.schema).from({{model_class}}.table)
      end
    end
  end
end
