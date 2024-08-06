require "spec"

require "sqlite3"
require "../src/cql"

Schema = Cql::Schema.new(
  database: :northwind,
  adapter: Cql::Adapter::Cqlite,
  db: DB.connect("sqlite3://spec/data.db")
)

Schema.table :customers do
  primary
  column :name, String
  column :city, String
  column :balance, Int64
  timestamps
end

Schema.table :users do
  primary
  column :name, String
  column :email, String
  timestamps
end

Schema.table :address do
  primary
  column :user_id, Int64, null: false
  column :street, String
  column :city, String
  column :zip, String
  timestamps
end

Schema.table :employees do
  primary
  column :name, String
  column :email, String
  column :phone, String
  column :department, String
  timestamps
end

struct CustomerModel
  include DB::Serializable

  property id : Int64
  property name : String
  property city : String
  property balance : Int64
  property created_at : Time
  property updated_at : Time

  def initialize(@id : Int64, @name : String, @city : String, @balance : Int64,
                 @created_at = Time.local, @updated_at = Time.local)
  end
end

def q
  Cql::Query.new(Schema)
end

def i
  Cql::Insert.new(Schema)
end

def u
  Cql::Update.new(Schema)
end

def d
  Cql::Delete.new(Schema)
end
