require "./spec_helper"

describe Cql::Query do
  describe "Basic SELECT queries" do
    it "selects all columns from tables" do
      select_query = Northwind.query.from(:customers, :users).to_sql

      output = <<-SQL
        SELECT customers.id, customers.name, customers.city, customers.balance, customers.created_at, customers.updated_at, users.id, users.name, users.email, users.age, users.created_at, users.updated_at FROM customers, users
      SQL

      select_query.should eq({output.strip, [] of DB::Any})
    end

    it "selects specific columns from a table" do
      select_query = Northwind.query
        .from(:customers)
        .select(:name, :city)
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city FROM customers
      SQL

      select_query.should eq({output.strip, [] of DB::Any})
    end

    it "uses DISTINCT in SELECT statement" do
      select_query = Northwind.query
        .from(:customers).distinct
        .select(:name, :city)
        .to_sql

      output = <<-SQL
        SELECT DISTINCT customers.name, customers.city FROM customers
      SQL

      select_query.should eq({output.strip, [] of DB::Any})
    end

    # it "handles subqueries in SELECT clause" do
    #   subquery = Northwind.query.from(:orders).select(:customer_id).where { orders.total > 1000 }
    #   select_query = Northwind.query
    #     .from(:customers)
    #     .select(:name, :city, subquery.as(:high_value_orders))
    #     .to_sql

    #   output = <<-SQL
    #     SELECT customers.name, customers.city,
    #     (SELECT orders.customer_id FROM orders WHERE orders.total > ?) AS high_value_orders
    #     FROM customers
    #   SQL

    #   select_query.should eq({output.strip, [1000]})
    # end
  end

  describe "WHERE clause" do
    it "handles WHERE clause with Symbol => DB::Value" do
      select_query = Northwind.query
        .from(:customers)
        .select(:name, :city)
        .where { (customers.name == "Tulum") & customers.city.eq("Kantenah") }
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city FROM customers WHERE (customers.name = ? AND customers.city = ?)
      SQL

      select_query.should eq({output.strip, ["Tulum", "Kantenah"]})
    end

    it "handles WHERE clause with Symbol => Value simple" do
      select_query = Northwind.query
        .from(:customers)
        .select(:name, :city)
        .where(name: "Tulum", city: "Kantenah")
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city FROM customers WHERE (customers.name = ? AND customers.city = ?)
      SQL

      select_query.should eq({output.strip, ["Tulum", "Kantenah"]})
    end

    it "handles complex WHERE query" do
      select_query_complex = Northwind.query
        .from(:users, :address)
        .select(users: [:id, :name], address: [:city, :street, :user_id])
        .where {
          (address.city == "Berlin") | (address.city == "London") & address.user_id.in [1, 2, 3]
        }.to_sql

      output = <<-SQL
        SELECT users.id, users.name, address.city, address.street, address.user_id FROM users, address WHERE (address.city = ? OR address.city = ? AND address.user_id IN (?, ?, ?))
      SQL

      select_query_complex.should eq({output.strip, ["Berlin", "London", 1, 2, 3]})
    end

    it "handles BETWEEN operator" do
      select_query = Northwind.query
        .from(:orders)
        .select(:id, :total)
        .where { orders.total.between(100, 1000) }
        .to_sql

      output = <<-SQL
        SELECT orders.id, orders.total FROM orders WHERE (orders.total BETWEEN ? AND ?)
      SQL

      select_query.should eq({output.strip, [100, 1000]})
    end

    it "handles IN operator with subquery" do
      subquery = Northwind.query.from(:orders).select(:customer_id).where { orders.total > 1000 }
      select_query = Northwind.query
        .from(:customers)
        .select(:name, :city)
        .where { customers.id.in(subquery) }
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city FROM customers WHERE (customers.id IN (SELECT orders.customer_id FROM orders WHERE (orders.total > ?)))
      SQL

      select_query.should eq({output.strip, [1000]})
    end
  end

  describe "ORDER BY, LIMIT, and other clauses" do
    it "handles ORDER BY clause" do
      select_query = Northwind.query
        .from(:customers)
        .select(:name, :city)
        .order(city: :desc, name: :asc)
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city FROM customers ORDER BY customers.city DESC, customers.name ASC
      SQL

      select_query.should eq({output.strip, [] of DB::Any})
    end

    it "handles LIMIT clause" do
      select_query = Northwind.query
        .from(:customers)
        .select(:name, :city)
        .limit(3)
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city FROM customers LIMIT ?
      SQL

      select_query.should eq({output.strip, [3]})
    end

    it "handles GROUP BY clause" do
      select_query = Northwind.query.from(:customers)
        .select(:city)
        .group(:city)
        .to_sql

      output = <<-SQL
        SELECT customers.city FROM customers GROUP BY customers.city
      SQL

      select_query.should eq({output.strip, [] of DB::Any})
    end

    it "handles HAVING clause" do
      select_query = Northwind.query
        .from(:customers)
        .select(:balance)
        .group(:city, :balance)
        .having { count(:balance) > 1 }
        .to_sql

      output = <<-SQL
        SELECT customers.balance FROM customers GROUP BY customers.city, customers.balance HAVING COUNT(customers.balance) > ?
      SQL

      select_query.should eq({output.strip, [1]})
    end

    it "handles OFFSET clause" do
      select_query = Northwind.query
        .from(:customers)
        .select(:name, :city)
        .limit(10)
        .offset(20)
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city FROM customers LIMIT ? OFFSET ?
      SQL

      select_query.should eq({output.strip, [10, 20]})
    end

    it "handles multiple GROUP BY columns" do
      select_query = Northwind.query
        .from(:orders)
        .select(:customer_id, :status, count: :id)
        .group(:customer_id, :status)
        .to_sql

      output = <<-SQL
        SELECT orders.customer_id, orders.status, COUNT(orders.id) FROM orders GROUP BY orders.customer_id, orders.status
      SQL

      select_query.should eq({output.strip, [] of DB::Any})
    end
  end

  describe "Aggregate functions" do
    it "uses COUNT in SELECT clause" do
      select_query = Northwind.query
        .from(:customers)
        .select(count: :id)
        .to_sql

      output = "SELECT COUNT(customers.id) FROM customers"
      select_query.should eq({output, [] of DB::Any})
    end

    it "uses SUM in SELECT clause" do
      select_query = Northwind.query
        .from(:orders)
        .select(sum: :total)
        .to_sql

      output = "SELECT SUM(orders.total) FROM orders"
      select_query.should eq({output, [] of DB::Any})
    end
  end

  describe "Indexes" do
    it "Creates indexes for table" do
      index = Cql::Index.new(Northwind.tables[:users], [:name, :email], unique: true)

      output = <<-SQL
        CREATE UNIQUE INDEX idx_name_emai ON users (name, email)
      SQL

      Expression::CreateIndex.new(index).accept(Expression::Generator.new).should eq(output.strip)
    end

    it "Creates non-unique index for table" do
      index = Cql::Index.new(Northwind.tables[:orders], [:customer_id, :order_date], unique: false)

      output = <<-SQL
        CREATE INDEX idx_cust_orde ON orders (customer_id, order_date)
      SQL

      Expression::CreateIndex.new(index).accept(Expression::Generator.new).should eq(output.strip)
    end
  end

  describe "Joins" do
    it "builds JOINS" do
      select_query = Northwind.query
        .from(:users)
        .select(users: [:name, :email], address: [:street, :city])
        .inner(:address, {
          Northwind.query.users.id    => Northwind.query.address.user_id,
          Northwind.query.users.name  => "John",
          Northwind.query.users.email => "john@example.com",
        }).to_sql

      output = <<-SQL.gsub(/\n/, " ").strip
        SELECT users.name, users.email, address.street, address.city
        FROM users
        INNER JOIN address ON users.id = address.user_id AND users.name = ? AND users.email = ?
        SQL
      select_query.should eq({output, ["John", "john@example.com"]})
    end

    it "build joins with block" do
      select_query = Northwind.query.from(:users)
        .select(users: [:name, :email], address: [:street, :city])
        .inner(:address) do
          users.id.eq(address.user_id) & users.name.eq("John") | users.id.eq(1)
        end.to_sql

      output = <<-SQL.gsub(/\n/, " ").strip
        SELECT users.name, users.email, address.street, address.city
        FROM users
        INNER JOIN address ON users.id = address.user_id AND users.name = ? OR users.id = ?
        SQL

      select_query.should eq({output, ["John", 1]})
    end

    it "combines join with where clause" do
      select_query = Northwind.query.from(:users)
        .select(users: [:name, :email], address: [:street, :city])
        .inner(:address) do
          users.id.eq(address.user_id)
        end
        .where do
          users.name.eq("John") | users.id.eq(1)
        end.to_sql

      output = <<-SQL.gsub(/\n/, " ").strip
        SELECT users.name, users.email, address.street, address.city
        FROM users
        INNER JOIN address ON users.id = address.user_id
        WHERE (users.name = ? OR users.id = ?)
        SQL

      select_query.should eq({output, ["John", 1]})
    end

  end

  describe "Transactions" do
    # it "handles basic transaction" do
    #   transaction = Northwind.transaction do |tx|
    #     tx.query.from(:customers).insert(name: "John Doe", city: "New York")
    #     tx.query.from(:orders).insert(customer_id: 1, total: 100)
    #   end

    #   expected_sql = [
    #     "BEGIN",
    #     "INSERT INTO customers (name, city) VALUES (?, ?)",
    #     "INSERT INTO orders (customer_id, total) VALUES (?, ?)",
    #     "COMMIT"
    #   ]

    #   transaction.to_sql.should eq(expected_sql)
    # end
  end
end
