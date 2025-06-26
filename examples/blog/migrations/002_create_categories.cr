require "../../../src/cql"

# =============================================================================
# CREATE CATEGORIES TABLE MIGRATION
# =============================================================================

class CreateCategories < CQL::Migration(2)
  def up
    schema.table :categories do
      primary :id, Int64, auto_increment: true
      column :name, String, null: false
      column :slug, String, null: false
      timestamps

      index [:slug], unique: true
    end

    schema.categories.create!
  end

  def down
    schema.categories.drop!
  end
end
