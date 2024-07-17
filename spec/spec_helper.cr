require "spec"
require "../src/sql"

Schema = Sql::Schema.new(:northwind)

Schema.table :customers do
  primary_key :customer_id, Int64, auto_increment: true
  column :name, String
  column :city, String
  column :balance, Int64
end

Schema.table :users do
  primary_key :id, Int64, auto_increment: true
  column :name, String
  column :email, String
end

Schema.table :address do
  primary_key :id, Int64, auto_increment: true
  column :user_id, Int64, null: false
  column :street, String
  column :city, String
  column :zip, String
end

Schema.table :employees do
  primary_key :id, Int64, auto_increment: true
  column :name, String
  column :email, String
  column :phone, String
  column :department, String
end

def q
  Sql::Query.new(Schema)
end

def i
  Sql::Insert.new(Schema)
end
