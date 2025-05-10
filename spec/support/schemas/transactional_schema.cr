DB_FILE = "spec/support/db/transactional_spec.db"

TestDBTransactional = CQL::Schema.define(
  :TestDBTransactional,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://spec/support/db/transactional_spec.db") do

  table :test_users_transactional do
    primary :id
    column :name, String
    column :email, String, null: true
  end
end
