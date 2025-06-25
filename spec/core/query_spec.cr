require "../spec_helper"

describe CQL::Query do
  describe "Basic SELECT queries" do
    it "selects all columns from tables" do
      select_query = Northwind.query.from(:customers, :users).to_sql

      # The generated SQL should include all expected columns from the schema
      # Note: This test is robust to schema changes (e.g., migrations adding columns)
      sql, params = select_query

      # Check that essential columns are present
      essential_customer_columns = ["customers.id", "customers.name", "customers.city", "customers.balance", "customers.user_id", "customers.created_at", "customers.updated_at"]
      essential_user_columns = ["users.id", "users.name", "users.email", "users.age", "users.created_at", "users.updated_at"]

      essential_customer_columns.each do |column|
        sql.should contain(column)
      end

      essential_user_columns.each do |column|
        sql.should contain(column)
      end

      # Verify the basic structure
      sql.should start_with("SELECT ")
      sql.should contain("FROM customers, users")
      params.should eq([] of DB::Any)
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
        .where { (customers.name.==("Tulum")) & customers.city.eq("Kantenah") }
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city FROM customers WHERE (customers.name = ?) AND (customers.city = ?)
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
        SELECT customers.name, customers.city FROM customers WHERE (customers.name = ?) AND (customers.city = ?)
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
        SELECT users.id, users.name, address.city, address.street, address.user_id FROM users, address WHERE (address.city = ?) OR ((address.city = ?) AND (address.user_id IN (?, ?, ?)))
      SQL

      select_query_complex.should eq({output.strip, ["Berlin", "London", 1, 2, 3]})
    end

    it "merges multiple WHERE clauses" do
      select_query = Northwind.query
        .from(:customers)
        .select(:name, :city)
        .where { customers.name.eq("Tulum") }
        .where { customers.city.eq("Kantenah") }
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city FROM customers WHERE (customers.name = ?) AND (customers.city = ?)
      SQL

      select_query.should eq({output.strip, ["Tulum", "Kantenah"]})
    end

    it "handles BETWEEN operator" do
      select_query = Northwind.query
        .from(:orders)
        .select(:id, :total)
        .where { orders.total.between(100, 1000) }
        .to_sql

      output = <<-SQL
        SELECT orders.id, orders.total FROM orders WHERE orders.total BETWEEN ? AND ?
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
        SELECT customers.name, customers.city FROM customers WHERE customers.id IN (SELECT orders.customer_id FROM orders WHERE orders.total > ?)
      SQL

      select_query.should eq({output.strip, [1000]})
    end

    it "handles array values in WHERE clause" do
      select_query = Northwind.query
        .from(:customers)
        .select(:name, :city)
        .where(id: [1, 2, 3])
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city FROM customers WHERE customers.id IN (?, ?, ?)
      SQL

      select_query.should eq({output.strip, [1, 2, 3]})
    end

    it "handles multiple array conditions in WHERE clause" do
      select_query = Northwind.query
        .from(:customers)
        .select(:name, :city)
        .where(id: [1, 2, 3], city: ["Rome", "Vienna"])
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city FROM customers WHERE (customers.id IN (?, ?, ?)) AND (customers.city IN (?, ?))
      SQL

      select_query.should eq({output.strip, [1, 2, 3, "Rome", "Vienna"]})
    end

    it "handles empty array in WHERE clause" do
      select_query = Northwind.query
        .from(:customers)
        .select(:name, :city)
        .where(id: [] of Int32)
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city FROM customers WHERE customers.id IN ()
      SQL

      select_query.should eq({output.strip, [] of DB::Any})
    end

    it "handles single element array in WHERE clause" do
      select_query = Northwind.query
        .from(:customers)
        .select(:name, :city)
        .where(id: [1])
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city FROM customers WHERE customers.id IN (?)
      SQL

      select_query.should eq({output.strip, [1]})
    end

    it "handles mixed data types in array WHERE clause" do
      select_query = Northwind.query
        .from(:orders)
        .select(:id, :status)
        .where(id: [1, 2, 3], status: ["pending", "completed"])
        .to_sql

      output = <<-SQL
        SELECT orders.id, orders.status FROM orders WHERE (orders.id IN (?, ?, ?)) AND (orders.status IN (?, ?))
      SQL

      select_query.should eq({output.strip, [1, 2, 3, "pending", "completed"]})
    end

    it "handles array values with other conditions in WHERE clause" do
      select_query = Northwind.query
        .from(:customers)
        .select(:name, :city, :balance)
        .where(id: [1, 2, 3], balance: 1000)
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city, customers.balance FROM customers WHERE (customers.id IN (?, ?, ?)) AND (customers.balance = ?)
      SQL

      select_query.should eq({output.strip, [1, 2, 3, 1000]})
    end

    it "handles array values in chained WHERE clauses" do
      select_query = Northwind.query
        .from(:customers)
        .select(:name, :city)
        .where(id: [1, 2, 3])
        .where(city: ["Rome", "Vienna"])
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city FROM customers WHERE (customers.id IN (?, ?, ?)) AND (customers.city IN (?, ?))
      SQL

      select_query.should eq({output.strip, [1, 2, 3, "Rome", "Vienna"]})
    end

    it "handles array values with block WHERE clause" do
      select_query = Northwind.query
        .from(:customers)
        .select(:name, :city)
        .where { customers.id.in([1, 2, 3]) & customers.city.in(["Rome", "Vienna"]) }
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city FROM customers WHERE (customers.id IN (?, ?, ?)) AND (customers.city IN (?, ?))
      SQL

      select_query.should eq({output.strip, [1, 2, 3, "Rome", "Vienna"]})
    end

    it "handles array values with complex block WHERE clause" do
      select_query = Northwind.query
        .from(:customers)
        .select(:name, :city, :balance)
        .where {
          customers.id.in([1, 2, 3]) &
            (customers.city.in(["Rome", "Vienna"]) | customers.balance.gt(500))
        }
        .to_sql

      output = <<-SQL
        SELECT customers.name, customers.city, customers.balance FROM customers WHERE (customers.id IN (?, ?, ?)) AND ((customers.city IN (?, ?)) OR (customers.balance > ?))
      SQL

      select_query.should eq({output.strip, [1, 2, 3, "Rome", "Vienna", 500]})
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
      index = CQL::Index.new(Northwind.tables[:users], [:name, :email], unique: true)

      output = <<-SQL
        CREATE UNIQUE INDEX idx_name_emai ON users (name, email)
      SQL

      Expression::CreateIndex.new(index).accept(Expression::Generator.new).should eq(output.strip)
    end

    it "Creates non-unique index for table" do
      index = CQL::Index.new(Northwind.tables[:orders], [:customer_id, :order_date], unique: false)

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
        .join(:address) { |j|
          j.users.id.eq(j.address.user_id) &
            j.users.name.eq("John") &
            j.users.email.eq("john@example.com")
        }
        .select(users: [:name, :email], address: [:street, :city])
        .to_sql

      output = <<-SQL.gsub(/\n/, " ").strip
        SELECT users.name, users.email, address.street, address.city FROM users INNER JOIN address ON ((users.id = address.user_id) AND (users.name = ?)) AND (users.email = ?)
        SQL

      select_query.should eq({output, ["John", "john@example.com"]})
    end

    it "build joins with block" do
      select_query = Northwind
        .query
        .from(:users)
        .join(:address) do |j|
          j.users.id.eq(j.address.user_id) & (j.users.name.eq("John") | j.users.id.eq(1))
        end
        .select(users: [:name, :email], address: [:street, :city])
        .to_sql

      output = <<-SQL.gsub(/\n/, " ").strip
        SELECT users.name, users.email, address.street, address.city FROM users INNER JOIN address ON (users.id = address.user_id) AND ((users.name = ?) OR (users.id = ?))
      SQL

      select_query.should eq({output, ["John", 1]})
    end

    it "combines join with where clause" do
      select_query = Northwind.query.from(:users)
        .from(:users)
        .join(:address) { |j| j.users.id.eq(j.address.user_id) }
        .select(users: [:name, :email], address: [:street, :city])
        .where { users.name.eq("John") | users.id.eq(1) }.to_sql

      output = <<-SQL.gsub(/\n/, " ").strip
        SELECT users.name, users.email, address.street, address.city FROM users INNER JOIN address ON users.id = address.user_id WHERE (users.name = ?) OR (users.id = ?)
      SQL

      select_query.should eq({output, ["John", 1]})
    end

    # Test with chained explicit joins using blocks
    it "supports chaining multiple joins with blocks" do
      select_query = Northwind.query
        .from(:orders)
        .join(:customers) { |builder| builder.orders.customer_id.eq(builder.customers.id) }
        .join(:users) { |builder| builder.customers.user_id.eq(builder.users.id) }
        .select(orders: [:id], customers: [:name], users: [:email])
        .to_sql

      output = <<-SQL.gsub(/\n/, " ").strip
        SELECT orders.id, customers.name, users.email FROM orders INNER JOIN customers ON orders.customer_id = customers.id INNER JOIN users ON customers.user_id = users.id
      SQL

      select_query.should eq({output, [] of DB::Any})
    end
  end

  describe "Inferred Joins" do
    # Assuming FK relationships: Address.user_id -> Users.id
    it "infers INNER JOIN based on foreign key" do
      select_query = Northwind.query
        .from(:users)
        .join(:address)
        .select(users: [:name], address: [:street])
        .to_sql

      # Assuming default alias is table name if Table#as_name is nil
      output = <<-SQL.gsub(/\n/, " ").strip
        SELECT users.name, address.street FROM users INNER JOIN address ON address.user_id = users.id
      SQL

      select_query.should eq({output, [] of DB::Any})
    end

    it "infers INNER JOIN with explicit alias" do
      select_query = Northwind.query
        .from(:users)
        .join(address: :addr)
        .select(users: [:name], addr: [:street])
        .to_sql

      output = <<-SQL.gsub(/\n/, " ").strip
        SELECT users.name, addr.street FROM users INNER JOIN address AS addr ON addr.user_id = users.id
      SQL

      select_query.should eq({output, [] of DB::Any})
    end

    # Assuming FK relationships: Orders.customer_id -> Customers.id
    it "infers LEFT JOIN using left_joins" do
      select_query = Northwind.query
        .from(:customers)
        .left(:orders)
        .select(customers: [:name], orders: [:id])
        .to_sql

      output = <<-SQL.gsub(/\n/, " ").strip
        SELECT customers.name, orders.id FROM customers LEFT JOIN orders ON orders.customer_id = customers.id
      SQL

      select_query.should eq({output, [] of DB::Any})
    end

    it "infers RIGHT JOIN using right_joins with alias" do
      select_query = Northwind.query
        .from(customers: :cust)
        .right(orders: :ord)
        .select(cust: [:name], ord: [:id])
        .to_sql

      output = <<-SQL.gsub(/\n/, " ").strip
        SELECT cust.name, ord.id FROM customers AS cust RIGHT JOIN orders AS ord ON ord.customer_id = cust.id
      SQL

      select_query.should eq({output, [] of DB::Any})
    end

    # Simple test with a single join between customers and orders
    it "infers multiple joins sequentially" do
      select_query = Northwind.query
        .from(:customers)
        .join(:orders) # Customers to Orders (using orders.customer_id FK)
        .select(customers: [:name], orders: [:id])
        .to_sql

      output = <<-SQL.gsub(/\n/, " ").strip
        SELECT customers.name, orders.id FROM customers INNER JOIN orders ON orders.customer_id = customers.id
      SQL

      select_query.should eq({output, [] of DB::Any})
    end

    it "uses aliases from 'from' clause for subsequent joins" do
      select_query = Northwind.query
        .from(users: :u)
        .join(:address) # Should join address ON u.id = address.user_id
        .select("u.name", address: [:street])
        .to_sql

      output = <<-SQL.gsub(/\n/, " ").strip
        SELECT u.name, address.street FROM users AS u INNER JOIN address ON address.user_id = u.id
      SQL

      select_query.should eq({output, [] of DB::Any})
    end

    # Test with chained explicit joins using blocks
    it "supports chaining multiple joins with blocks" do
      select_query = Northwind.query
        .from(:orders)
        .join(:customers) { |inner| inner.orders.customer_id.eq(inner.customers.id) }
        .join(:users) { |inner| inner.customers.user_id.eq(inner.users.id) }
        .select(orders: [:id], customers: [:name], users: [:email])
        .to_sql

      output = <<-SQL.gsub(/\n/, " ").strip
        SELECT orders.id, customers.name, users.email FROM orders INNER JOIN customers ON orders.customer_id = customers.id INNER JOIN users ON customers.user_id = users.id
      SQL

      select_query.should eq({output, [] of DB::Any})
    end
  end

  describe "Query merging" do
    it "merges two simple queries with different select columns and where clauses" do
      query1 = Northwind.query.from(:customers).select(:name).where { customers.city == "London" }
      query2 = Northwind.query.from(:customers).select(:balance).where { customers.balance > 1000 }

      query1.merge(query2)
      sql, params = query1.to_sql

      expected_sql = "SELECT customers.name, customers.balance FROM customers WHERE (customers.city = ?) AND (customers.balance > ?)"
      expected_params = ["London", 1000] of DB::Any

      sql.should eq(expected_sql)
      params.should eq(expected_params)
    end

    it "handles distinct correctly when merging" do
      query1 = Northwind.query.from(:customers).select(:city)
      query2 = Northwind.query.from(:customers).select(:name).distinct # Assuming name exists, just need a column

      query1.merge(query2)
      sql, _ = query1.to_sql
      sql.should contain("SELECT DISTINCT customers.city, customers.name") # Merged distinct and columns

      query3 = Northwind.query.from(:customers).select(:city).distinct
      query4 = Northwind.query.from(:customers).select(:name)
      query3.merge(query4)
      sql, _ = query3.to_sql
      sql.should contain("SELECT DISTINCT customers.city, customers.name")
    end

    it "merges order by clauses, with the merged query's order taking precedence and adding new ones" do
      query1 = Northwind.query.from(:customers).select(:name, :city, :balance).order(name: :asc, city: :asc)
      query2 = Northwind.query.from(:customers).order(city: :desc, balance: :desc) # Overwrites city, adds balance

      query1.merge(query2)
      sql, _ = query1.to_sql

      # Expected orders: name ASC, city DESC, balance DESC. The SQL string can have them in any sequence after ORDER BY.
      sql.should contain("ORDER BY")
      order_by_clause = sql.split("ORDER BY")[1].strip

      # Check for presence of all three with correct directions
      order_by_clause.should contain("customers.name ASC")
      order_by_clause.should contain("customers.city DESC")
      order_by_clause.should contain("customers.balance DESC")

      # Count the number of order conditions to ensure no extras/missing
      # 3 conditions means 2 commas. Split by comma and check parts.
      order_parts = order_by_clause.split(',').map(&.strip)
      order_parts.size.should eq(3)
      order_parts.should contain("customers.name ASC")
      order_parts.should contain("customers.city DESC")
      order_parts.should contain("customers.balance DESC")
    end

    it "merges limit clauses, taking the smaller limit if both are set" do
      query1 = Northwind.query.from(:customers).limit(10)
      query2 = Northwind.query.from(:customers).limit(5)
      query1.merge(query2)
      sql, params = query1.to_sql
      sql.should contain("LIMIT ?")
      params.should eq([5] of DB::Any)

      query3 = Northwind.query.from(:customers).limit(3)
      query4 = Northwind.query.from(:customers) # No limit
      query3.merge(query4)
      sql, params = query3.to_sql
      sql.should contain("LIMIT ?")
      params.should eq([3] of DB::Any)

      query5 = Northwind.query.from(:customers) # No limit
      query6 = Northwind.query.from(:customers).limit(7)
      query5.merge(query6)
      sql, params = query5.to_sql
      sql.should contain("LIMIT ?")
      params.should eq([7] of DB::Any)
    end

    it "merges offset clauses, with the merged query's offset taking precedence or persisting" do
      # Test 1: q1 has offset, q2 has offset -> q2 wins
      q_offset1 = Northwind.query.from(:customers).limit(10).offset(5)
      q_offset2 = Northwind.query.from(:customers).limit(10).offset(15)
      q_offset1.merge(q_offset2)
      sql, params_offset1 = q_offset1.to_sql
      sql.should eq("SELECT customers.id, customers.name, customers.city, customers.balance, customers.user_id, customers.created_at, customers.updated_at FROM customers LIMIT ? OFFSET ?")
      params_offset1.should eq([10, 15] of DB::Any)

      # Test 2: q1 has offset, q2 has NO offset -> q1's offset persists
      q_offset3 = Northwind.query.from(:customers).limit(10).offset(5)
      q_offset4 = Northwind.query.from(:customers).limit(10) # No offset
      q_offset3.merge(q_offset4)
      sql, params_offset3 = q_offset3.to_sql
      sql.should eq("SELECT customers.id, customers.name, customers.city, customers.balance, customers.user_id, customers.created_at, customers.updated_at FROM customers LIMIT ? OFFSET ?")
      params_offset3.should eq([10, 5] of DB::Any)

      # Test 3: q1 has NO offset, q2 has offset -> q2's offset is applied
      q_offset5 = Northwind.query.from(:customers).limit(10)
      q_offset6 = Northwind.query.from(:customers).limit(10).offset(25)
      q_offset5.merge(q_offset6)
      sql, params_offset5 = q_offset5.to_sql
      sql.should eq("SELECT customers.id, customers.name, customers.city, customers.balance, customers.user_id, customers.created_at, customers.updated_at FROM customers LIMIT ? OFFSET ?")
      params_offset5.should eq([10, 25] of DB::Any)
    end

    it "merges joins correctly, combining tables and join conditions" do
      query1 = Northwind.query.from(:users).select("users.name").join(:address) { |builder| builder.users.id.eq(builder.address.user_id) }
      query2 = Northwind.query.from(:customers).select("customers.name").join(:orders) { |builder| builder.customers.id.eq(builder.orders.customer_id) }

      query1.merge(query2)
      sql, _ = query1.to_sql

      # Expected: SELECT users.name, address.*, customers.name, orders.* (or similar, depending on implicit select from join)
      # FROM users, customers INNER JOIN address ON ... INNER JOIN orders ON ...
      # The exact SELECT columns depend on how implicit selections for joined tables are handled post-merge.
      # The merge logic for columns is `@columns.concat(other_query.columns).uniq!`.
      # If joins don't add to `@columns` themselves, then only explicitly selected columns appear.
      # `build_select` adds all columns from `@query_tables` if `@columns` is empty.
      # After merge, `@columns` will be `[users.name, customers.name]`. So implicit * won't happen.

      sql.should contain("SELECT users.name, customers.name FROM users, customers")
      sql.should contain("INNER JOIN address ON users.id = address.user_id")
      sql.should contain("INNER JOIN orders ON customers.id = orders.customer_id")
    end

    it "raises an error if schemas are different" do
      query1 = Northwind.query # Uses Northwind.schema

      # Create a distinct schema instance
      # This assumes CQL::Schema.new creates a new instance without problematic side effects for this test.
      expect_raises(ArgumentError, "Cannot merge queries: Schemas are different.") do
        query1.merge(Billing.query)
      end
    end

    it "raises an error on conflicting table aliases for different tables" do
      query1 = Northwind.query.from(users: :u)
      # Ensure 'products' table exists in Northwind schema for this test to be valid
      query2 = Northwind.query.from(employees: :u)

      expect_raises(ArgumentError, /Merge conflict: Alias 'u'/) do
        query1.merge(query2)
      end
    end

    it "does not raise error for same alias referring to the same table" do
      query3 = Northwind.query.from(users: :u1).select("u1.name")
      query4 = Northwind.query.from(users: :u1).select("u1.email")

      query3.merge(query4)

      sql, _ = query3.to_sql
      # Should select u1.name, u1.email FROM users AS u1
      sql.should contain("SELECT u1.name, u1.email FROM users AS u1")
      # Ensure FROM clause is not duplicated
      sql.scan("FROM users AS u1").size.should eq(1)
    end

    it "merges group by and having clauses" do
      query1 = Northwind.query.from(:orders).select(:customer_id).group(:customer_id)
      query2 = Northwind.query.from(:orders).select(sum: :total).group(:status).having { sum(:total) > 1000 }

      query1.merge(query2)
      sql, params = query1.to_sql

      sql.should eq("SELECT orders.customer_id, SUM(orders.total) FROM orders GROUP BY orders.customer_id, orders.status HAVING SUM(orders.total) > ?")
      params.should eq([1000] of DB::Any)

      # Test merging when original query already has a having clause
      query3 = Northwind.query.from(:orders).select(:customer_id, count: :id).group(:customer_id).having { count(:id) > 5 }
      query4 = Northwind.query.from(:orders).select(sum: :total).group(:status).having { sum(:total) < 500 }

      query3.merge(query4)
      sql, params = query3.to_sql

      # SELECTs merged: customer_id, COUNT(id), SUM(total)
      # GROUP BYs merged: customer_id, status
      # HAVINGs merged: (current) AND (other)
      expected_sql = "SELECT orders.customer_id, COUNT(orders.id), SUM(orders.total) FROM orders GROUP BY orders.customer_id, orders.status HAVING (COUNT(orders.id) > ?) AND (SUM(orders.total) < ?)"
      sql.should eq(expected_sql)
      # Params order: first from query3's having, then from query4's having
      # Assuming count returns Int64 and sum compares with Int32 as per example
      expected_params = [5_i64, 500] of DB::Any
      params.should eq(expected_params)
    end

    it "merges query_tables correctly, adding new tables and respecting aliases" do
      query1 = Northwind.query.from(users: :u).select("u.name")
      query2 = Northwind.query.from(employees: :p).select("p.name")

      query1.merge(query2)
      sql, _ = query1.to_sql
      # Expected: SELECT u.name, p.name FROM users AS u, products AS p (order of tables in FROM might vary)
      sql.should contain("SELECT u.name, p.name")
      from_clause = sql.split("SELECT ")[1].split(" WHERE")[0] # Get content between SELECT and WHERE (or end of string)
      from_clause.should contain("FROM users AS u")
      from_clause.should contain("employees AS p")
      from_clause.scan(",").size.should eq(2) # Ensure two tables in FROM, separated by one comma

      # Test merging when other_query introduces a table already in current_query (no alias conflict)
      query_a = Northwind.query.from(:users).select(:name)
      query_b = Northwind.query.from(:users, :orders).select(:email, orders: [:id])

      query_a.merge(query_b)
      sql_a, _ = query_a.to_sql
      # Expected SQL: SELECT users.name, users.email, orders.id FROM users, orders
      sql_a.should contain("SELECT users.name, users.email, orders.id")
      from_clause_a = sql_a.split("SELECT ")[1].split(" WHERE")[0]
      from_clause_a.should contain("FROM users")
      from_clause_a.should contain("orders")
      from_clause_a.scan(",").size.should eq(3) # users, orders
    end
  end
end
