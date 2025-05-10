require "../spec_helper"

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
      count_query.first!(as: Int64).should eq 2

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

  describe "foreign key operations" do
    before_each do
      TableDB.books.drop! rescue nil
      TableDB.authors.drop! rescue nil
      TableDB.products.drop! rescue nil
      TableDB.categories.drop! rescue nil
      TableDB.order_items.drop! rescue nil
      TableDB.orders.drop! rescue nil
      TableDB.children.drop! rescue nil
      TableDB.parents.drop! rescue nil
      TableDB.users.drop! rescue nil
      TableDB.posts.drop! rescue nil
      TableDB.ref_table.drop! rescue nil
      TableDB.test_table.drop! rescue nil
      TableDB.test_table2.drop! rescue nil
    end

    it "adds a simple foreign key referencing the primary key implicitly" do
      TableDB.table(:authors) do
        primary :id, Int64
        column :name, String
      end

      books_table = TableDB.table(:books) do
        primary :id, Int64
        column :title, String
        integer :author_id
        foreign_key :author_id, references: :authors
      end

      books_table.foreign_keys.size.should eq 1

      fk = books_table.foreign_keys.first
      fk.should_not be_nil
      fk.table.should eq books_table
      fk.columns.should eq [:author_id]
      fk.references_table.should eq :authors
      fk.references_columns.should eq [:id]
      fk.on_delete.should eq :no_action
      fk.on_update.should eq :no_action
      fk.name.should be_nil
    end

    it "adds a foreign key with explicit referenced column and ON DELETE/UPDATE actions" do
      TableDB.table(:categories) do
        primary :category_uid, UUID
        column :name, String
      end

      products_table = TableDB.table(:products) do
        primary :id, Int64
        column :name, String
        varchar :category_ref
        foreign_key :category_ref,
          references: :categories,
          references_columns: :category_uid,
          on_delete: :cascade,
          on_update: :restrict,
          name: "fk_prod_cat"
      end

      products_table.foreign_keys.size.should eq 1

      fk = products_table.foreign_keys.first
      fk.should_not be_nil
      fk.table.should eq products_table
      fk.columns.should eq [:category_ref]
      fk.references_table.should eq :categories
      fk.references_columns.should eq [:category_uid]
      fk.on_delete.should eq :cascade
      fk.on_update.should eq :restrict
      fk.name.should eq "fk_prod_cat"
    end

    it "adds a composite foreign key referencing a single table" do
      TableDB.table(:orders) do
        integer :order_group
        integer :order_number
      end

      table = TableDB.table(:order_items) do
        primary :id, Int64
        integer :group_ref
        integer :num_ref
        foreign_key [:group_ref, :num_ref],
          references: :orders,
          references_columns: [:order_group, :order_number],
          name: "fk_order_item_details"
      end

      table.foreign_keys.size.should eq 1
      fk = table.foreign_keys.first
      fk.should_not be_nil
      fk.table.should eq table
      fk.columns.should eq [:group_ref, :num_ref]
      fk.references_table.should eq :orders
      fk.references_columns.should eq [:order_group, :order_number]
      fk.name.should eq "fk_order_item_details"
    end

    it "raises error if referenced columns count mismatch" do
      TableDB.table(:ref_table) do
        primary :id1, Int32
        integer :id2
      end

      expect_raises(ArgumentError, "Number of columns (col1) must match number of referenced columns (id1, id2)") do
        TableDB.table(:test_table) do
          integer :col1
          foreign_key :col1, references: :ref_table, references_columns: [:id1, :id2]
        end
      end

      expect_raises(ArgumentError, "Number of columns (col1, col2) must match number of referenced columns (id1)") do
        TableDB.table(:test_table2) do
          integer :col1
          integer :col2
          foreign_key [:col1, :col2], references: :ref_table, references_columns: :id1
        end
      end
    end
  end

  describe "SQL generation" do
    it "generates create table SQL for simple table" do
      customers_table = TableDB.table(:customers) do
        primary :id, Int32, auto_increment: false
        column :name, String
        column :city, String
        column :balance, Int32
      end

      sql = customers_table.create_sql

      sql.should contain("CREATE TABLE IF NOT EXISTS customers")
      sql.should contain("id INTEGER PRIMARY KEY")
      sql.should contain("name TEXT NOT NULL")
      sql.should contain("city TEXT NOT NULL")
      sql.should contain("balance INTEGER NOT NULL")
      sql.should_not contain("FOREIGN KEY")
    end

    it "generates create table SQL with foreign key" do
      TableDB.table(:users) { primary :id, Int64 }

      posts_table = TableDB.table(:posts) do
        primary :id, Int64
        column :title, String
        integer :user_id
        foreign_key :user_id, references: :users, on_delete: :cascade, name: "fk_posts_users"
      end

      sql = posts_table.create_sql
      sql.should contain("CREATE TABLE IF NOT EXISTS posts")
      sql.should contain("id INTEGER PRIMARY KEY AUTOINCREMENT")
      sql.should contain("title TEXT NOT NULL")
      sql.should contain("user_id INTEGER NOT NULL")
      sql.should contain("FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION")
    end

    it "generates create table SQL with composite foreign key" do
      TableDB.table(:parents) do
        primary :pk1, Int32
        integer :pk2
      end

      children_table = TableDB.table(:children) do
        primary :id, Int64
        integer :fk1
        integer :fk2
        foreign_key [:fk1, :fk2], references: :parents, references_columns: [:pk1, :pk2], name: "fk_child_parent"
      end

      sql = children_table.create_sql
      sql.should contain("CREATE TABLE IF NOT EXISTS children")
      sql.should contain("id INTEGER PRIMARY KEY AUTOINCREMENT")
      sql.should contain("fk1 INTEGER NOT NULL")
      sql.should contain("fk2 INTEGER NOT NULL")
      sql.should contain("FOREIGN KEY (fk1, fk2) REFERENCES parents (pk1, pk2) ON DELETE NO ACTION ON UPDATE NO ACTION")
    end

    it "generates drop table SQL" do
      customers_table = TableDB.table(:customers) do
        primary :id, Int32
        column :name, String
        column :city, String
        column :balance, Int32
      end

      sql = customers_table.drop_sql
      sql.should eq("DROP TABLE IF EXISTS customers")
    end

    it "generates truncate table SQL" do
      customers_table = TableDB.table(:customers) do
        primary :id, Int32
        column :name, String
        column :city, String
        column :balance, Int32
      end

      sql = customers_table.truncate_sql
      sql.should eq("DELETE FROM customers")
    end
  end

  describe "column type methods" do
    it "adds integer column" do
      customers_table = TableDB.table(:customers) do
        integer :age
      end
      col = customers_table.integer(:age)
      col.should be_a(CQL::Column(Int32))
    end

    it "adds bigint column" do
      customers_table = TableDB.table(:customers) do
        bigint :big_number
      end
      col = customers_table.bigint(:big_number)
      col.should be_a(CQL::Column(Int64))
    end

    it "adds float column" do
      customers_table = TableDB.table(:customers) do
        float :score
      end
      col = customers_table.float(:score)
      col.should be_a(CQL::Column(Float32))
    end

    it "adds double column" do
      customers_table = TableDB.table(:customers) do
        double :precise_score
      end
      col = customers_table.double(:precise_score)
      col.should be_a(CQL::Column(Float64))
    end

    it "adds text column" do
      customers_table = TableDB.table(:customers) do
        text :description
      end
      col = customers_table.text(:description)
      col.should be_a(CQL::Column(String))
    end

    it "adds varchar column" do
      customers_table = TableDB.table(:customers) do
        varchar :code, size: 50
      end
      col = customers_table.varchar(:code, size: 50)
      col.should be_a(CQL::Column(String))
      col.as(CQL::Column(String)).@size.should eq(50)
    end

    it "adds boolean column" do
      customers_table = TableDB.table(:customers) do
        boolean :active
      end
      col = customers_table.boolean(:active)
      col.should be_a(CQL::Column(Bool))
    end

    it "adds timestamp column" do
      customers_table = TableDB.table(:customers) do
        timestamp :login_at
      end
      col = customers_table.timestamp(:login_at)
      col.should be_a(CQL::Column(Time))
    end

    it "adds date column" do
      customers_table = TableDB.table(:customers) do
        date :birth_date
      end
      col = customers_table.date(:birth_date)
      col.should be_a(CQL::Column(Time))
    end

    it "adds json column" do
      customers_table = TableDB.table(:customers) do
        json :metadata
      end
      col = customers_table.json(:metadata)
      col.should be_a(CQL::Column(JSON::Any))
    end

    it "adds interval column" do
      customers_table = TableDB.table(:customers) do
        interval :duration
      end
      col = customers_table.interval(:duration)
      col.should be_a(CQL::Column(Time::Span))
    end

    it "adds blob column" do
      customers_table = TableDB.table(:customers) do
        blob :data
      end
      col = customers_table.blob(:data)
      col.should be_a(CQL::Column(Slice(UInt8)))
    end
  end

  describe "constraint operations" do
    before_each do
      # Ensure tables are clean before each test
      TableDB.products.drop! rescue nil
      TableDB.users.drop! rescue nil
    end

    it "adds a unique constraint to the table definition" do
      products_table = TableDB.table(:products) do
        primary :id, Int64
        column :sku, String
        column :supplier_code, String
        unique_constraint [:sku]
        unique_constraint [:supplier_code, :sku], name: "uk_product_supplier"
      end

      products_table.unique_constraints.size.should eq 2

      uc1 = products_table.unique_constraints[0]
      uc1.columns.should eq [:sku]
      uc1.name.should be_nil

      uc2 = products_table.unique_constraints[1]
      uc2.columns.should eq [:supplier_code, :sku]
      uc2.name.should eq "uk_product_supplier"
    end

    it "adds a check constraint to the table definition" do
      products_table = TableDB.table(:products) do
        primary :id, Int64
        integer :price
        integer :stock_level
        check_constraint "price > 0"
        check_constraint "stock_level >= 0", name: "chk_stock"
      end

      products_table.check_constraints.size.should eq 2

      cc1 = products_table.check_constraints[0]
      cc1.condition.should eq "price > 0"
      cc1.name.should be_nil

      cc2 = products_table.check_constraints[1]
      cc2.condition.should eq "stock_level >= 0"
      cc2.name.should eq "chk_stock"
    end
  end

  describe "SQL generation" do
    it "generates create table SQL for simple table" do
      customers_table = TableDB.table(:customers) do
        primary :id, Int32, auto_increment: false
        column :name, String
        column :city, String
        column :balance, Int32
      end

      sql = customers_table.create_sql

      sql.should contain("CREATE TABLE IF NOT EXISTS customers")
      sql.should contain("id INTEGER PRIMARY KEY")
      sql.should contain("name TEXT NOT NULL")
      sql.should contain("city TEXT NOT NULL")
      sql.should contain("balance INTEGER NOT NULL")
      sql.should_not contain("FOREIGN KEY")
    end

    it "generates create table SQL with foreign key" do
      TableDB.table(:users) { primary :id, Int64 }

      posts_table = TableDB.table(:posts) do
        primary :id, Int64
        column :title, String
        integer :user_id
        foreign_key :user_id, references: :users, on_delete: :cascade, name: "fk_posts_users"
      end

      sql = posts_table.create_sql
      sql.should contain("CREATE TABLE IF NOT EXISTS posts")
      sql.should contain("id INTEGER PRIMARY KEY AUTOINCREMENT")
      sql.should contain("title TEXT NOT NULL")
      sql.should contain("user_id INTEGER NOT NULL")
      sql.should contain("FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION")
    end

    it "generates create table SQL with composite foreign key" do
      TableDB.table(:parents) do
        primary :pk1, Int32
        integer :pk2
      end

      children_table = TableDB.table(:children) do
        primary :id, Int64
        integer :fk1
        integer :fk2
        foreign_key [:fk1, :fk2], references: :parents, references_columns: [:pk1, :pk2], name: "fk_child_parent"
      end

      sql = children_table.create_sql
      sql.should contain("CREATE TABLE IF NOT EXISTS children")
      sql.should contain("id INTEGER PRIMARY KEY AUTOINCREMENT")
      sql.should contain("fk1 INTEGER NOT NULL")
      sql.should contain("fk2 INTEGER NOT NULL")
      sql.should contain("FOREIGN KEY (fk1, fk2) REFERENCES parents (pk1, pk2) ON DELETE NO ACTION ON UPDATE NO ACTION")
    end

    it "generates create table SQL with unique constraint" do
      users_table = TableDB.table(:users) do
        primary :id, Int64
        column :email, String
        unique_constraint [:email], name: "uk_user_email"
      end

      sql = users_table.create_sql
      sql.should contain("CREATE TABLE IF NOT EXISTS users")
      sql.should contain("id INTEGER PRIMARY KEY AUTOINCREMENT")
      sql.should contain("email TEXT NOT NULL")
      sql.should contain("CONSTRAINT uk_user_email UNIQUE (email)")
    end

    it "generates create table SQL with multiple unique constraints" do
      products_table = TableDB.table(:products) do
        primary :id, Int64
        column :sku, String
        column :upc, String
        unique_constraint [:sku]
        unique_constraint [:upc], name: "uk_product_upc"
      end

      sql = products_table.create_sql
      sql.should contain("UNIQUE (sku)")
      sql.should contain("CONSTRAINT uk_product_upc UNIQUE (upc)")
    end

    it "generates create table SQL with check constraint" do
      products_table = TableDB.table(:products) do
        primary :id, Int64
        integer :price
        check_constraint "price > 10", name: "chk_product_price"
      end

      sql = products_table.create_sql
      sql.should contain("CREATE TABLE IF NOT EXISTS products")
      sql.should contain("id INTEGER PRIMARY KEY AUTOINCREMENT")
      sql.should contain("price INTEGER NOT NULL")
      sql.should contain("CONSTRAINT chk_product_price CHECK (price > 10)")
    end

    it "generates create table SQL with multiple check constraints" do
      products_table = TableDB.table(:products) do
        primary :id, Int64
        integer :price
        integer :discount
        check_constraint "price > 0"
        check_constraint "discount < price", name: "chk_discount_logic"
      end

      sql = products_table.create_sql
      sql.should contain("CHECK (price > 0)")
      sql.should contain("CONSTRAINT chk_discount_logic CHECK (discount < price)")
    end

    it "generates create table SQL with mixed constraints" do
      orders_table = TableDB.table(:orders) do
        primary :id, Int64
        integer :user_id
        integer :total_amount
        varchar :status

        foreign_key :user_id, references: :users
        unique_constraint [:user_id, :id] # Example composite unique key
        check_constraint "total_amount >= 0"
        check_constraint "status IN ('pending', 'completed', 'cancelled')", name: "chk_order_status"
      end

      # Need a dummy users table for the foreign key reference
      TableDB.table(:users) { primary :id, Int64 }

      sql = orders_table.create_sql
      sql.should contain("FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE NO ACTION ON UPDATE NO ACTION")
      sql.should contain("UNIQUE (user_id, id)")
      sql.should contain("CHECK (total_amount >= 0)")
      sql.should contain("CONSTRAINT chk_order_status CHECK (status IN ('pending', 'completed', 'cancelled'))")
    end

    it "generates drop table SQL" do
      customers_table = TableDB.table(:customers) do
        primary :id, Int32
        column :name, String
        column :city, String
        column :balance, Int32
      end

      sql = customers_table.drop_sql
      sql.should eq("DROP TABLE IF EXISTS customers")
    end

    it "generates truncate table SQL" do
      customers_table = TableDB.table(:customers) do
        primary :id, Int32
        column :name, String
        column :city, String
        column :balance, Int32
      end

      sql = customers_table.truncate_sql
      sql.should eq("DELETE FROM customers")
    end
  end

  describe "column type methods" do
    it "adds integer column" do
      customers_table = TableDB.table(:customers) do
        integer :age
      end
      col = customers_table.integer(:age)
      col.should be_a(CQL::Column(Int32))
    end

    it "adds bigint column" do
      customers_table = TableDB.table(:customers) do
        bigint :big_number
      end
      col = customers_table.bigint(:big_number)
      col.should be_a(CQL::Column(Int64))
    end

    it "adds float column" do
      customers_table = TableDB.table(:customers) do
        float :score
      end
      col = customers_table.float(:score)
      col.should be_a(CQL::Column(Float32))
    end

    it "adds double column" do
      customers_table = TableDB.table(:customers) do
        double :precise_score
      end
      col = customers_table.double(:precise_score)
      col.should be_a(CQL::Column(Float64))
    end

    it "adds text column" do
      customers_table = TableDB.table(:customers) do
        text :description
      end
      col = customers_table.text(:description)
      col.should be_a(CQL::Column(String))
    end

    it "adds varchar column" do
      customers_table = TableDB.table(:customers) do
        varchar :code, size: 50
      end
      col = customers_table.varchar(:code, size: 50)
      col.should be_a(CQL::Column(String))
      col.as(CQL::Column(String)).@size.should eq(50)
    end

    it "adds boolean column" do
      customers_table = TableDB.table(:customers) do
        boolean :active
      end
      col = customers_table.boolean(:active)
      col.should be_a(CQL::Column(Bool))
    end

    it "adds timestamp column" do
      customers_table = TableDB.table(:customers) do
        timestamp :login_at
      end
      col = customers_table.timestamp(:login_at)
      col.should be_a(CQL::Column(Time))
    end

    it "adds date column" do
      customers_table = TableDB.table(:customers) do
        date :birth_date
      end
      col = customers_table.date(:birth_date)
      col.should be_a(CQL::Column(Time))
    end

    it "adds json column" do
      customers_table = TableDB.table(:customers) do
        json :metadata
      end
      col = customers_table.json(:metadata)
      col.should be_a(CQL::Column(JSON::Any))
    end

    it "adds interval column" do
      customers_table = TableDB.table(:customers) do
        interval :duration
      end
      col = customers_table.interval(:duration)
      col.should be_a(CQL::Column(Time::Span))
    end

    it "adds blob column" do
      customers_table = TableDB.table(:customers) do
        blob :data
      end
      col = customers_table.blob(:data)
      col.should be_a(CQL::Column(Slice(UInt8)))
    end
  end
end
