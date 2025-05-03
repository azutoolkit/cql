require "./spec_helper"

describe CQL::Table do
  describe "initialization" do
    it "creates a table with valid name" do
      table = TableDB.table(:customers) do
        primary :id, Int32
        column :name, String
        column :city, String
        column :balance, Int32
        timestamps
      end
      table.table_name.should eq :customers
    end

    it "raises error for empty table name" do
      expect_raises(CQL::Error, "Table name cannot be empty") do
        CQL::Table.new(:"", TableDB)
      end
    end

    it "raises error for table name with spaces" do
      expect_raises(CQL::Error, "Table name cannot contain spaces") do
        CQL::Table.new(:"my table", TableDB)
      end
    end

    it "raises error for table name starting with number" do
      expect_raises(CQL::Error, "Table name cannot start with a number") do
        CQL::Table.new(:"1users", TableDB)
      end
    end
  end

  describe "column operations" do
    it "adds primary key column" do
      table = TableDB.table(:customers) do
        primary :id, Int64
      end
      primary = table.primary(:id, Int64)
      primary.should be_a(CQL::PrimaryKey(Int64))
      primary.name.should eq :id
      primary.as(CQL::PrimaryKey(Int64)).auto_increment?.should be_true
      primary.as(CQL::PrimaryKey(Int64)).unique?.should be_true
    end

    it "adds regular column" do
      table = TableDB.table(:customers) do
        column :name, String
      end
      column = table.column(:name, String)
      column.should be_a(CQL::Column(String))
      column.name.should eq :name
      column.null?.should be_false
    end

    it "adds indexed column" do
      table = TableDB.table(:customers) do
        column :email, String, index: true, unique: true
      end
      column = table.column(:email, String, index: true, unique: true)
      column.should be_a(CQL::Column(String))
      column.index?.should_not be_nil
      column.index?.not_nil!.unique?.should be_true
    end

    it "adds timestamps" do
      table = TableDB.table(:customers) do
        timestamps
      end
      table.timestamps
      table.columns[:created_at]?.should_not be_nil
      table.columns[:updated_at]?.should_not be_nil
    end
  end

  describe "table operations" do
    it "creates table" do
      table = TableDB.table(:customers) do
        primary :id, Int32
        column :name, String
        column :city, String
        column :email, String
        column :balance, Int32
        timestamps
      end
      table.drop! rescue nil
      table.create!

      customer = CustomerModel.new(1, "John", "john@example.com", "New York", 100)

      TableDB.insert.into(:customers).values(
        name: customer.name,
        city: customer.city,
        email: customer.email,
        balance: customer.balance,
        created_at: customer.created_at,
        updated_at: customer.updated_at
      ).commit

      persisted = TableDB.query.from(:customers).first!(as: CustomerModel)

      persisted.id.should eq customer.id
      persisted.name.should eq customer.name
      persisted.city.should eq customer.city
      persisted.balance.should eq customer.balance
    end

    it "truncates table" do
      table = TableDB.table(:customers) do
        primary :id, Int32
        column :name, String
        column :city, String
        column :email, String
        column :balance, Int32
        timestamps
      end
      table.drop! rescue nil
      table.create!

      customers = [
        {
          :name       => "John",
          :city       => "New York",
          :email      => "john@example.com",
          :balance    => 100,
          :created_at => Time.local,
          :updated_at => Time.local,
        } of Symbol => DB::Any,
        {
          :name       => "Jane",
          :city       => "New York",
          :email      => "jane@example.com",
          :balance    => 200,
          :created_at => Time.local,
          :updated_at => Time.local,
        } of Symbol => DB::Any,
      ]

      TableDB
        .insert
        .into(:customers)
        .values(customers)
        .commit

      count_query = TableDB.query.from(:customers).count
      count_query.first!(as: Int32).should eq 2

      table.truncate!
      count_query.first!(as: Int32).should eq 0
    end

    it "drops table" do
      table = TableDB.table(:customers) do
        primary :id, Int32
        column :name, String
        column :city, String
        column :email, String
        column :balance, Int32
        timestamps
      end
      table.create! rescue nil
      table.drop!
      check_query = "SELECT name FROM sqlite_master WHERE type='table' AND name='customers'"

      expect_raises(DB::NoResultsError) do
        TableDB.exec_query(&.query_one(check_query, as: String))
      end
    end
  end

  describe "SQL generation" do
    it "generates create table SQL" do
      table = TableDB.table(:customers) do
        primary :id, Int32, auto_increment: false
        column :name, String
        column :city, String
        column :balance, Int32
      end
      sql = table.create_sql
      sql.should contain("CREATE TABLE IF NOT EXISTS customers")
      sql.should contain("id INTEGER PRIMARY KEY")
      sql.should contain("name TEXT NOT NULL")
      sql.should contain("city TEXT NOT NULL")
      sql.should contain("balance INTEGER NOT NULL")
    end

    it "generates drop table SQL" do
      table = TableDB.table(:customers) do
        primary :id, Int32
        column :name, String
        column :city, String
        column :balance, Int32
      end
      sql = table.drop_sql
      sql.should eq("DROP TABLE IF EXISTS customers")
    end

    it "generates truncate table SQL" do
      table = TableDB.table(:customers) do
        primary :id, Int32
        column :name, String
        column :city, String
        column :balance, Int32
      end
      sql = table.truncate_sql
      sql.should eq("DELETE FROM customers")
    end
  end

  describe "column type methods" do
    it "adds integer column" do
      table = TableDB.table(:customers) do
        integer :age
      end
      col = table.integer(:age)
      col.should be_a(CQL::Column(Int32))
    end

    it "adds bigint column" do
      table = TableDB.table(:customers) do
        bigint :big_number
      end
      col = table.bigint(:big_number)
      col.should be_a(CQL::Column(Int64))
    end

    it "adds float column" do
      table = TableDB.table(:customers) do
        float :score
      end
      col = table.float(:score)
      col.should be_a(CQL::Column(Float32))
    end

    it "adds double column" do
      table = TableDB.table(:customers) do
        double :precise_score
      end
      col = table.double(:precise_score)
      col.should be_a(CQL::Column(Float64))
    end

    it "adds text column" do
      table = TableDB.table(:customers) do
        text :description
      end
      col = table.text(:description)
      col.should be_a(CQL::Column(String))
    end

    it "adds varchar column" do
      table = TableDB.table(:customers) do
        varchar :code, size: 50
      end
      col = table.varchar(:code, size: 50)
      col.should be_a(CQL::Column(String))
      col.as(CQL::Column(String)).@size.should eq(50)
    end

    it "adds boolean column" do
      table = TableDB.table(:customers) do
        boolean :active
      end
      col = table.boolean(:active)
      col.should be_a(CQL::Column(Bool))
    end

    it "adds timestamp column" do
      table = TableDB.table(:customers) do
        timestamp :login_at
      end
      col = table.timestamp(:login_at)
      col.should be_a(CQL::Column(Time))
    end

    it "adds date column" do
      table = TableDB.table(:customers) do
        date :birth_date
      end
      col = table.date(:birth_date)
      col.should be_a(CQL::Column(Time))
    end

    it "adds json column" do
      table = TableDB.table(:customers) do
        json :metadata
      end
      col = table.json(:metadata)
      col.should be_a(CQL::Column(JSON::Any))
    end

    it "adds interval column" do
      table = TableDB.table(:customers) do
        interval :duration
      end
      col = table.interval(:duration)
      col.should be_a(CQL::Column(Time::Span))
    end

    it "adds blob column" do
      table = TableDB.table(:customers) do
        blob :data
      end
      col = table.blob(:data)
      col.should be_a(CQL::Column(Slice(UInt8)))
    end
  end
end
