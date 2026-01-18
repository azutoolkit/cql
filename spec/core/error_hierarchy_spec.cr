require "../spec_helper"

describe "Error Hierarchy" do
  describe "CQL::Error base class" do
    it "is the base class for all CQL errors" do
      # CQL::Error should inherit from Exception
      error = CQL::Error.new("test")
      error.is_a?(Exception).should be_true
    end
  end

  describe "Schema errors" do
    it "Schema::Error inherits from CQL::Error" do
      error = CQL::Schema::Error.new("test")
      error.is_a?(CQL::Error).should be_true
    end

    it "Schema::InvalidURIError inherits from Schema::Error and CQL::Error" do
      error = CQL::Schema::InvalidURIError.new("test")
      error.is_a?(CQL::Schema::Error).should be_true
      error.is_a?(CQL::Error).should be_true
    end

    it "Schema::VersionConflictError inherits from Schema::Error and CQL::Error" do
      error = CQL::Schema::VersionConflictError.new("test")
      error.is_a?(CQL::Schema::Error).should be_true
      error.is_a?(CQL::Error).should be_true
    end

    it "Schema::ConnectionError inherits from Schema::Error and CQL::Error" do
      error = CQL::Schema::ConnectionError.new("test")
      error.is_a?(CQL::Schema::Error).should be_true
      error.is_a?(CQL::Error).should be_true
    end
  end

  describe "SchemaDump errors" do
    it "SchemaDump::Error inherits from CQL::Error" do
      error = CQL::SchemaDump::Error.new("test")
      error.is_a?(CQL::Error).should be_true
    end
  end

  describe "Migrator errors" do
    it "Migrator::Error inherits from CQL::Error" do
      error = CQL::Migrator::Error.new("test")
      error.is_a?(CQL::Error).should be_true
    end
  end

  describe "Relation errors" do
    it "RelationError inherits from CQL::Error" do
      error = CQL::ActiveRecord::Relations::BaseRelation::RelationError.new("test")
      error.is_a?(CQL::Error).should be_true
    end

    it "AssociationNotFound inherits from RelationError and CQL::Error" do
      error = CQL::ActiveRecord::Relations::BaseRelation::AssociationNotFound.new("test")
      error.is_a?(CQL::ActiveRecord::Relations::BaseRelation::RelationError).should be_true
      error.is_a?(CQL::Error).should be_true
    end

    it "InvalidAssociation inherits from RelationError and CQL::Error" do
      error = CQL::ActiveRecord::Relations::BaseRelation::InvalidAssociation.new("test")
      error.is_a?(CQL::ActiveRecord::Relations::BaseRelation::RelationError).should be_true
      error.is_a?(CQL::Error).should be_true
    end

    it "UnsavedRecord inherits from RelationError and CQL::Error" do
      error = CQL::ActiveRecord::Relations::BaseRelation::UnsavedRecord.new("test")
      error.is_a?(CQL::ActiveRecord::Relations::BaseRelation::RelationError).should be_true
      error.is_a?(CQL::Error).should be_true
    end
  end

  describe "unified error handling" do
    it "rescue CQL::Error catches Schema::InvalidURIError" do
      rescued = false
      begin
        raise CQL::Schema::InvalidURIError.new("test")
      rescue CQL::Error
        rescued = true
      end
      rescued.should be_true
    end

    it "rescue CQL::Error catches SchemaDump::Error" do
      rescued = false
      begin
        raise CQL::SchemaDump::Error.new("test")
      rescue CQL::Error
        rescued = true
      end
      rescued.should be_true
    end

    it "rescue CQL::Error catches Migrator::Error" do
      rescued = false
      begin
        raise CQL::Migrator::Error.new("test")
      rescue CQL::Error
        rescued = true
      end
      rescued.should be_true
    end

    it "rescue CQL::Error catches RelationError" do
      rescued = false
      begin
        raise CQL::ActiveRecord::Relations::BaseRelation::RelationError.new("test")
      rescue CQL::Error
        rescued = true
      end
      rescued.should be_true
    end

    it "rescue CQL::Error catches AssociationNotFound" do
      rescued = false
      begin
        raise CQL::ActiveRecord::Relations::BaseRelation::AssociationNotFound.new("test")
      rescue CQL::Error
        rescued = true
      end
      rescued.should be_true
    end
  end
end
