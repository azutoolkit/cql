module CQL
  module ActiveRecord
    module Relations
      alias BaseAssocMetadata = CQL::ActiveRecord::Relations::BaseAssociationMetadata

      abstract class BaseAssociationMetadata
        abstract def target_class : Class
        abstract def foreign_key : Symbol
        abstract def primary_key : Symbol
        abstract def type : Symbol
      end

      # AssociationMetadata stores information about model associations
      class AssociationMetadata < BaseAssociationMetadata
        getter target_class : BaseAssocMetadata = BaseAssocMetadata.class
        getter foreign_key : Symbol
        getter primary_key : Symbol
        getter type : Symbol

        def initialize(@target_class, @foreign_key, @primary_key, @type)
        end
      end

      # AssociationStorage provides methods to manage loaded associations
      module AssociationStorage
        # Stores the loaded associations for a model
        @loaded_associations : Hash(Symbol, Array(BaseAssocMetadata)) = {} of Symbol => Array(BaseAssocMetadata)

        # Sets a loaded association
        # - **param** : name (Symbol) - The name of the association
        # - **param** : records (Array(T)) - The loaded records
        # - **return** : Nil
        def set_loaded_association(name : Symbol, records : Array(BaseAssocMetadata))
          @loaded_associations[name] = records
        end

        # Gets a loaded association
        # - **param** : name (Symbol) - The name of the association
        # - **return** : Array(T)?
        def get_loaded_association(name : Symbol) : Array(BaseAssocMetadata)?
          @loaded_associations[name]?
        end

        # Checks if an association is loaded
        # - **param** : name (Symbol) - The name of the association
        # - **return** : Bool
        def association_loaded?(name : Symbol) : Bool
          @loaded_associations.has_key?(name)
        end

        # Clears all loaded associations
        # - **return** : Nil
        def clear_loaded_associations
          @loaded_associations.clear
        end
      end

      # AssociationMetadata provides methods to manage association metadata
      module Associations
        # Stores the association metadata for a model
        @@association_metadata : Hash(Symbol, BaseAssociationMetadata) = {} of Symbol => BaseAssociationMetadata

        # Gets the association metadata for a model
        # - **return** : Hash(Symbol, CQL::ActiveRecord::Model::AssociationMetadata)
        def self.association_metadata : Hash(Symbol, BaseAssociationMetadata)
          @@association_metadata
        end

        # Adds association metadata
        # - **param** : name (Symbol) - The name of the association
        # - **param** : target_class (Class) - The target model class
        # - **param** : foreign_key (Symbol) - The foreign key column
        # - **param** : primary_key (Symbol) - The primary key column
        # - **param** : type (Symbol) - The type of association
        # - **return** : Nil
        def self.add_association(name : Symbol, target_class : Class, foreign_key : Symbol, primary_key : Symbol, type : Symbol)
          @@association_metadata[name] = AssociationMetadata.new(target_class, foreign_key, primary_key, type)
        end

        # Gets association metadata for a specific association
        # - **param** : name (Symbol) - The name of the association
        # - **return** : CQL::ActiveRecord::Model::AssociationMetadata?
        def self.get_association(name : Symbol) : BaseAssociationMetadata?
          @@association_metadata[name]?
        end
      end
    end
  end
end
