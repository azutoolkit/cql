TableDB = Cql::Schema.build(
  name: :tabledb,
  adapter: Cql::Adapter::Sqlite,
  uri: "sqlite3://spec/db/tabledb.db") do
  table :customers do
    primary :id, Int32
    column :name, String
    column :city, String
    column :balance, Int32
    timestamps
  end

  table :users do
    primary :id, Int32
    column :name, String
    column :email, String
    column :age, Int32
    timestamps
  end

  table :address do
    primary :id, Int32
    column :user_id, Int64, null: false
    column :street, String
    column :city, String
    column :zip, String
    timestamps
  end

  table :employees do
    primary :id, Int32
    column :name, String
    column :email, String
    column :phone, String
    column :department, String
    timestamps
  end
end
