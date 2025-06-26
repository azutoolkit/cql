require "../../../src/cql"

# =============================================================================
# CREATE POSTS TABLE MIGRATION
# =============================================================================

class CreatePosts < CQL::Migration(3)
  def up
    schema.table :posts do
      primary :id, Int64, auto_increment: true
      column :title, String, null: false
      column :content, String, null: false
      column :published, Bool, default: false
      column :views_count, Int64, default: 0
      column :user_id, Int64, null: false
      column :category_id, Int64, null: true
      timestamps

      foreign_key [:user_id], references: :users, references_columns: [:id]
      foreign_key [:category_id], references: :categories, references_columns: [:id]

      index [:published]
      index [:user_id]
      index [:category_id]
    end

    schema.posts.create!
  end

  def down
    schema.posts.drop!
  end
end
