AppSchema = CQL::Schema.define(
  :app_schema,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://spec/support/db/northwind.db") do
  table :schema_migrations do
    primary :id, Int32
    text :name
    integer :version
    timestamps
  end

end
