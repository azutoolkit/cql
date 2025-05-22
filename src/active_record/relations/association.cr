module CQL::ActiveRecord::Relations
  abstract class BaseAssociation
    alias Options = Hash(Symbol, Bool | Symbol)
    abstract def target_model
  end

  # Represents the metadata for a model association
  class Association(TargetModel) < BaseAssociation
    getter name : Symbol
    getter type : Symbol
    getter foreign_key : Symbol
    getter options : Options? = nil

    def initialize(
      @name : Symbol,
      @type : Symbol,
      @target_model : TargetModel.class,
      @foreign_key : Symbol,
      @options : Options? = nil)
    end

    def target_model
      TargetModel
    end
  end

  # Module to provide association registration functionality
  module AssociationRegistry
    macro included
      # Class variable to store association definitions
      @@associations = {} of Symbol => BaseAssociation

      # Register an association definition
      def self.register_association(name : Symbol, type : Symbol, target_model : T.class, foreign_key : Symbol, **options) forall T
        @@associations[name] = Association(T).new(name, type, target_model, foreign_key, nil)
      end

      # Get an association definition by name
      def self.association(name : Symbol) : BaseAssociation?
        @@associations[name]?
      end

      # Get all association definitions
      def self.associations : Hash(Symbol, BaseAssociation)
        @@associations
      end
    end
  end
end
