# Define a database module for our example
module MyApp
  DB = CQL::Schema.define(
    name: :scopes_spec_my_app,
    adapter: CQL::Adapter::SQLite,
    uri: "sqlite3://spec/support/db/scopes_spec.db") do
    table :scopes_posts do
      primary :id, Int64
      varchar :title
      varchar :body
      boolean :published
      varchar :category
      timestamps
    end
  end
end
