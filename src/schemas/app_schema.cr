AppSchema = CQL::Schema.define(
  :app_schema,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://examples/blog/blog.db") do
  table :cql_schema_migrations do
    primary :id, Int32
    text :name
    integer :version
    timestamps
  end

  table :users do
    primary :id, Int32
    text :username
    text :email
    text :first_name, null: true
    text :last_name, null: true
    boolean :active, default: "1"
    timestamps
  end

  table :categories do
    primary :id, Int32
    text :name
    text :slug
    timestamps
  end

  table :posts do
    primary :id, Int32
    text :title
    text :content
    boolean :published, default: "0"
    bigint :views_count, default: "0"
    bigint :user_id
    bigint :category_id, null: true
    timestamps
    foreign_key [:category_id], references: :categories, references_columns: [:id], on_delete: :no_action, on_update: :no_action
    foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: :no_action, on_update: :no_action
  end

  table :comments do
    primary :id, Int32
    text :content
    bigint :post_id
    bigint :user_id, null: true
    timestamps
    foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: :no_action, on_update: :no_action
    foreign_key [:post_id], references: :posts, references_columns: [:id], on_delete: :no_action, on_update: :no_action
  end

end
