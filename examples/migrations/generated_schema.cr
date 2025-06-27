GeneratedSchema = CQL::Schema.define(
  :generated_schema,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://examples/migration_example.db") do
  table :schema_migrations do
    primary :id, Int32
    text :name
    integer :version
    timestamps
  end
end
