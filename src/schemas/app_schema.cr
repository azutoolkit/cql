AppSchema = CQL::Schema.define(
  :app_schema,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://spec/support/db/northwind.db") do
  table :cql_schema_migrations do
    primary :id, Int32
    text :name
    bigint :version
    timestamps
  end

  table :users do
    primary :id, Int32
    text :name
    text :email
    integer :age
    text :phone, null: true
    timestamps
  end
end
