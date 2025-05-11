Northwind = CQL::Schema.define(
  name: :northwind,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://spec/support/db/northwind.db") do
  table :customers do
    primary :id, Int32
    column :name, String
    column :city, String
    column :balance, Int32
    column :user_id, Int32, null: false
    timestamps

    # Add foreign key to users table
    foreign_key [:user_id], references: :users, references_columns: [:id]
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

    # Add foreign key to users table
    foreign_key [:user_id], references: :users, references_columns: [:id]
  end

  table :employees do
    primary :id, Int32
    column :name, String
    column :email, String
    column :phone, String
    column :department, String
    timestamps
  end

  table :orders do
    primary :id, Int32
    integer :total, default: 0
    column :customer_id, Int32, null: false
    column :employee_id, Int32, null: false
    column :order_date, Time
    text :status, default: "pending"
    column :shipped_date, Time
    column :shipper_id, Int32
    timestamps

    # Add foreign key to customers table
    foreign_key [:customer_id], references: :customers, references_columns: [:id]
    # Add foreign key to employees table
    foreign_key [:employee_id], references: :employees, references_columns: [:id]
  end
end
