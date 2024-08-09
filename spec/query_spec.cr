require "./spec_helper"

describe Cql::Query do
  it "selects all columns from tables" do
    select_query = Northwind.query.from(:customers, :users).to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.id, customers.name, customers.city, customers.balance, customers.created_at,
      customers.updated_at, users.id, users.name, users.email, users.age, users.created_at, users.updated_at
      FROM customers, users
      SQL

    select_query.should eq({output, [] of DB})
  end

  it "select data from a database" do
    select_query = Northwind.query
      .from(:customers)
      .select(:name, :city)
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
    SELECT customers.name, customers.city FROM customers
    SQL

    select_query.should eq({output, [] of DB})
  end

  it "SELECT DISTINCT Statement" do
    select_query = Northwind.query
      .from(:customers).distinct
      .select(:name, :city)
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT DISTINCT customers.name, customers.city FROM customers
      SQL

    select_query.should eq({output, [] of DB})
  end

  it "WHERE Clause with Symbol => DB::Value" do
    select_query = Northwind.query
      .from(:customers)
      .select(:name, :city)
      .where { (customers.name == "Tulum") & customers.city.eq("Kantenah") }
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (customers.name = ? AND customers.city = ?)
      SQL

    select_query.should eq({output, ["Tulum", "Kantenah"]})
  end

  it "WHERE Clause with Symbol => Value simple" do
    select_query = Northwind.query
      .from(:customers)
      .select(:name, :city)
      .where(name: "Tulum", city: "Kantenah")
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (customers.name = ? AND customers.city = ?)
      SQL

    select_query.should eq({output, ["Tulum", "Kantenah"]})
  end

  it "raises error when column is not right type" do
    expect_raises Cql::Error, "Expected column `name` to be String, but got Int32" do
      Northwind.query.from(:customers)
        .select(:name, :city)
        .where { customers.name == 1 }
        .to_sql
    end
  end

  it "WHERE complex query" do
    select_query_complex = Northwind.query
      .from(:users, :address)
      .select(users: [:id, :name], address: [:city, :street, :user_id])
      .where {
        (address.city == "Berlin") | (address.city == "London") & address.user_id.in [1, 2, 3]
      }.to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT users.id, users.name, address.city, address.street, address.user_id
      FROM users, address
      WHERE (address.city = ? OR address.city = ? AND address.user_id IN (?, ?, ?))
      SQL

    select_query_complex.should eq({output, ["Berlin", "London", 1, 2, 3]})
  end

  it "ORDER BY" do
    select_query = Northwind.query
      .from(:customers)
      .select(:name, :city)
      .order(city: :desc, name: :asc)
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      ORDER BY customers.city DESC, customers.name ASC
      SQL

    select_query.should eq({output, [] of DB})
  end

  it "like operator" do
    select_query = Northwind.query
      .from(:customers)
      .select(:name, :city)
      .where { customers.city.like("a%") }
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (customers.city LIKE ?)
      SQL

    select_query.should eq({output, ["a%"]})
  end

  it "NOT Operator" do
    select_query = Northwind.query
      .from(:customers)
      .select(:name, :city)
      .where { (customers.city != "hello") }
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (customers.city != ?)
      SQL
    select_query.should eq({output, ["hello"]})
  end

  it "NOT LIKE Operator" do
    select_query = Northwind.query
      .from(:customers)
      .select(:name, :city)
      .where { customers.city.not_like("a%") }
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (customers.city NOT LIKE ?)
      SQL
    select_query.should eq({output, ["a%"]})
  end

  it "IS NULL Operator" do
    select_query = Northwind.query
      .from(:customers)
      .select(:name, :city)
      .where { customers.city.null }
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (customers.city IS NULL)
      SQL
    select_query.should eq({output, [] of DB})
  end

  it "IS NOT NULL Operator" do
    select_query = Northwind.query
      .from(:customers)
      .select(:name, :city)
      .where { customers.city.not_null }
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (customers.city IS NOT NULL)
      SQL
    select_query.should eq({output, [] of DB})
  end

  it "SELECT LIMIT Clause" do
    select_query = Northwind.query
      .from(:customers)
      .select(:name, :city)
      .limit(3)
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      LIMIT ?
      SQL

    select_query.should eq({output, [3]})
  end

  it "EXISTS Operator" do
    sub_query = Northwind.query.from(:users)
      .select(:id)
      .where { users.id == 1 }

    select_query = Northwind.query.from(:customers)
      .select(:name, :city)
      .where { exists?(sub_query) }
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (EXISTS (SELECT users.id FROM users WHERE (users.id = ?)))
      SQL
    select_query.should eq({output, [1]})
  end

  it "creates GROUP BY clause" do
    select_query = Northwind.query.from(:customers)
      .select(:city)
      .group(:city)
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.city
      FROM customers
      GROUP BY customers.city
      SQL

    select_query.should eq({output, [] of DB})

    select_query = Northwind.query.from(:customers)
      .select(:city)
      .group(:city, :name)
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.city
      FROM customers
      GROUP BY customers.city, customers.name
      SQL

    select_query.should eq({output, [] of DB})
  end

  it "HAVING Clause" do
    select_query = Northwind.query
      .from(:customers)
      .select(:balance)
      .group(:city, :balance)
      .having { count(:balance) > 1 }
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.balance
      FROM customers
      GROUP BY customers.city, customers.balance
      HAVING COUNT(customers.balance) > ?
      SQL

    select_query.should eq({output, [1]})
  end

  it "Select query with GROUP BY clause" do
    select_query = Northwind.query
      .from(:employees)
      .select(:department)
      .group(:department)
      .order(:department)
      .to_sql
    output = <<-SQL.gsub(/\n/, " ").strip
      SELECT employees.department
      FROM employees
      GROUP BY employees.department
      ORDER BY employees.department ASC
      SQL

    select_query.should eq({output, [] of DB})
  end

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

  it "Creates indexes for table" do
    index = Cql::Index.new(Northwind.tables[:users], [:name, :email], unique: true)

    Expression::CreateIndex.new(index).accept(Expression::Generator.new).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      CREATE UNIQUE INDEX idx_name_emai ON users (name, email)
      SQL
    )
  end
end
