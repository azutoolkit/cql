require "../../../src/cql"

# =============================================================================
# CREATE USERS TABLE MIGRATION
# =============================================================================

class CreateUsers < CQL::Migration(1)
  def up
    schema.table :users do
      primary :id, Int64, auto_increment: true
      column :username, String, null: false
      column :email, String, null: false
      column :first_name, String, null: true
      column :last_name, String, null: true
      column :active, Bool, default: true
      timestamps

      index [:email], unique: true
      index [:username], unique: true
    end

    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end
