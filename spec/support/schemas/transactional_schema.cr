DB_FILE = File.join(CQLSpecSupport.sqlite_db_dir, "transactional_spec.db")

TestDBTransactional = CQL::Schema.define(
  :TestDBTransactional,
  adapter: CQL::Adapter::SQLite,
  uri: spec_sqlite_uri("transactional_spec.db")) do
  table :test_users_transactional do
    primary :id
    column :name, String
    column :email, String, null: true
  end
end
