require "../../../src/cql"

# =============================================================================
# CREATE COMMENTS TABLE MIGRATION
# =============================================================================

class CreateComments < CQL::Migration(4)
  def up
    schema.table :comments do
      primary :id, Int64, auto_increment: true
      column :content, String, null: false
      column :post_id, Int64, null: false
      column :user_id, Int64, null: true
      timestamps

      foreign_key [:post_id], references: :posts, references_columns: [:id]
      foreign_key [:user_id], references: :users, references_columns: [:id]

      index [:post_id]
      index [:user_id]
    end

    schema.comments.create!
  end

  def down
    schema.comments.drop!
  end
end
