require "./spec_helper"

describe Sql do
  generator = Expression::Generator.new

  it "selects all columns from tables" do
    select_query = q
      .from(:customers, :users)
      .build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.customer_id, customers.name, customers.city, customers.balance, users.id, users.name, users.email
      FROM customers, users
      SQL
    )
  end

  it "select data from a database" do
    select_query = q
      .from(:customers)
      .select(:name, :city)
      .build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city FROM customers
      SQL
    )
  end

  it "SELECT DISTINCT Statement" do
    select_query = q
      .from(:customers).distinct
      .select(:name, :city)
      .build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT DISTINCT customers.name, customers.city FROM customers
      SQL
    )
  end

  it "WHERE Clause with Symbol => DB::Value" do
    select_query = q
      .from(:customers)
      .select(:name, :city)
      .where { (customers.name == "'Tulum'") & customers.city.eq("'Kantenah'") }
      .build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (customers.name = 'Tulum' AND customers.city = 'Kantenah')
      SQL
    )
  end

  it "WHERE Clause with Symbol => Value simple" do
    select_query = q
      .from(:customers)
      .select(:name, :city)
      .where(name: "'Tulum'", city: "'Kantenah'").build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (customers.name = 'Tulum' AND customers.city = 'Kantenah')
      SQL
    )
  end

  it "WHERE complex query" do
    select_query_complex = q
      .from(:users, :address)
      .select(users: [:id, :name], address: [:city, :street, :user_id])
      .where {
        (address.city == "'Berlin'") | (address.city == "'London'") & address.user_id.in [1, 2, 3]
      }.build

    select_query_complex.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT users.id, users.name, address.city, address.street, address.user_id
      FROM users, address
      WHERE (address.city = 'Berlin' OR address.city = 'London' AND address.user_id IN (1, 2, 3))
      SQL
    )
  end

  it "ORDER BY" do
    select_query = q
      .from(:customers)
      .select(:name, :city)
      .order(city: :desc, name: :asc)
      .build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      ORDER BY customers.city DESC, customers.name ASC
      SQL
    )
  end

  it "like operator" do
    select_query = q
      .from(:customers)
      .select(:name, :city)
      .where { customers.city.like("'a%'") }
      .build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (customers.city LIKE 'a%')
      SQL
    )
  end

  it "NOT Operator" do
    select_query = q
      .from(:customers)
      .select(:name, :city)
      .where { (customers.city != "'hello'") }.build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (customers.city != 'hello')
      SQL
    )
  end

  it "NOT LIKE Operator" do
    select_query = q
      .from(:customers)
      .select(:name, :city)
      .where { customers.city.not_like("'a%'") }.build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (customers.city NOT LIKE 'a%')
      SQL
    )
  end

  it "IS NULL Operator" do
    select_query = q
      .from(:customers)
      .select(:name, :city)
      .where { customers.city.null }.build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (customers.city IS NULL)
      SQL
    )
  end

  it "IS NOT NULL Operator" do
    select_query = q
      .from(:customers)
      .select(:name, :city)
      .where { customers.city.not_null }.build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (customers.city IS NOT NULL)
      SQL
    )
  end

  it "SELECT LIMIT Clause" do
    select_query = q
      .from(:customers)
      .select(:name, :city)
      .limit(3)
      .build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      LIMIT 3
      SQL
    )
  end

  it "EXISTS Operator" do
    sub_query = q.from(:users)
      .select(:id)
      .where { users.id == 1 }

    select_query = q.from(:customers)
      .select(:name, :city)
      .where { exists?(sub_query) }
      .build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (EXISTS (SELECT users.id FROM users WHERE (users.id = 1)))
      SQL
    )
  end

  it "creates GROUP BY clause" do
    select_query = q.from(:customers)
      .select(:city)
      .group(:city)
      .build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.city
      FROM customers
      GROUP BY customers.city
      SQL
    )

    select_query = q.from(:customers)
      .select(:city)
      .group(:city, :name)
      .build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.city
      FROM customers
      GROUP BY customers.city, customers.name
      SQL
    )
  end

  it "HAVING Clause" do
    select_query = q
      .from(:customers)
      .select(:balance)
      .group(:city, :balance)
      .having { count(:balance) > 1 }
      .build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.balance
      FROM customers
      GROUP BY customers.city, customers.balance
      HAVING COUNT(customers.balance) > 1
      SQL
    )
  end

  it "Select query with GROUP BY clause" do
    select_query = q
      .from(:employees)
      .select(:department)
      .group(:department)
      .order(:department)
      .build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT employees.department
      FROM employees
      GROUP BY employees.department
      ORDER BY employees.department ASC
      SQL
    )
  end

  it "builds JOINS" do
    select_query = q
      .from(:users)
      .select(users: [:name, :email], address: [:street, :city])
      .inner(:address, {q.users.id => q.address.user_id, q.users.name => "'John'", q.users.email => "'john@example.com'"})
      .build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT users.name, users.email, address.street, address.city
      FROM users
      INNER JOIN address ON users.id = address.user_id AND users.name = 'John' AND users.email = 'john@example.com'
      SQL
    )
  end

  it "build joins with block" do
    select_query = q.from(:users)
      .select(users: [:name, :email], address: [:street, :city])
      .inner(:address) do
        (users.id.eq(address.user_id)) & (users.name.eq("'John'")) | (users.id.eq(1))
      end.build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT users.name, users.email, address.street, address.city
      FROM users
      INNER JOIN address ON users.id = address.user_id AND users.name = 'John' OR users.id = 1
      SQL
    )
  end

  it "creates Inset Into query" do
    insert_query = i.into(:users).values(name: "'John'", email: "'john@example.com'").build

    insert_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      INSERT INTO users (users.name, users.email) VALUES ('John', 'john@example.com')
      SQL
    )
  end

  it "creates Inset Into query with multiple rows" do
    insert_query = i.into(:users)
      .values(name: "'John'", email: "'john@example.com'")
      .values(name: "'Jane'", email: "'jane@example.com'")
      .build

    insert_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      INSERT INTO users (users.name, users.email)
      VALUES ('John', 'john@example.com'), ('Jane', 'jane@example.com')
      SQL
    )
  end

  it "creates Inset Into query with returning clause" do
    insert_query = i.into(:users)
      .values(name: "'John'", email: "'jane@example.com'")
      .back(:id)
      .build

    insert_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      INSERT INTO users (users.name, users.email) VALUES ('John', 'jane@example.com') RETURNING (users.id)
      SQL
    )
  end

  it "creates Inset Into with select query" do
    select_query = q.from(:users)
      .select(:name, :email)
      .where { users.id == 1 }

    insert_query = i.into(:users)
      .query(select_query)
      .build

    insert_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      INSERT INTO users (users.name, users.email) SELECT users.name, users.email FROM users WHERE (users.id = 1)
      SQL
    )
  end
end
