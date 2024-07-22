require "./spec_helper"

describe Sql do
  it "selects all columns from tables" do
    select_query = q
      .from(:customers, :users)
      .to_sql

    select_query.should eq(
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
      .to_sql

    select_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city FROM customers
      SQL
    )
  end

  it "SELECT DISTINCT Statement" do
    select_query = q
      .from(:customers).distinct
      .select(:name, :city)
      .to_sql

    select_query.should eq(
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
      .to_sql

    select_query.should eq(
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
      .where(name: "'Tulum'", city: "'Kantenah'")
      .to_sql

    select_query.should eq(
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
      }.to_sql

    select_query_complex.should eq(
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
      .to_sql

    select_query.should eq(
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
      .to_sql

    select_query.should eq(
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
      .where { (customers.city != "'hello'") }
      .to_sql

    select_query.should eq(
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
      .where { customers.city.not_like("'a%'") }
      .to_sql

    select_query.should eq(
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
      .where { customers.city.null }
      .to_sql

    select_query.should eq(
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
      .where { customers.city.not_null }
      .to_sql

    select_query.should eq(
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
      .to_sql

    select_query.should eq(
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
      .to_sql

    select_query.should eq(
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
      .to_sql

    select_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.city
      FROM customers
      GROUP BY customers.city
      SQL
    )

    select_query = q.from(:customers)
      .select(:city)
      .group(:city, :name)
      .to_sql

    select_query.should eq(
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
      .to_sql

    select_query.should eq(
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
      .to_sql

    select_query.should eq(
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
      .inner(:address, {
        q.users.id    => q.address.user_id,
        q.users.name  => "'John'",
        q.users.email => "'john@example.com'",
      })
      .to_sql

    select_query.should eq(
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
      end.to_sql

    select_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT users.name, users.email, address.street, address.city
      FROM users
      INNER JOIN address ON users.id = address.user_id AND users.name = 'John' OR users.id = 1
      SQL
    )
  end

  it "Delete specific rows that meet a certain condition." do
    delete_query = d.from(:users)
      .where { users.id == 1 }
      .to_sql

    delete_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      DELETE FROM users WHERE (users.id = 1)
      SQL
    )
  end

  it "Delete rows based on the result of a subquery." do
    sub_query = q.from(:users)
      .select(:id)
      .where { users.id == 1 }

    delete_query = d.from(:users)
      .where { exists?(sub_query) }
      .to_sql

    delete_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      DELETE FROM users WHERE (EXISTS (SELECT users.id FROM users WHERE (users.id = 1)))
      SQL
    )
  end

  it "Delete rows from one table based on a condition in another table using a join." do
    delete_query = d.from(:users)
      .using(:address)
      .where { (users.id == address.user_id) & (address.city == "'Berlin'") }
      .to_sql

    delete_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      DELETE FROM users USING address WHERE (users.id = address.user_id AND address.city = 'Berlin')
      SQL
    )
  end

  it "Delete rows and return the deleted rows." do
    delete_query = d.from(:users)
      .where { users.id == 1 }
      .back(:id)
      .to_sql

    delete_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      DELETE FROM users WHERE (users.id = 1) RETURNING (users.id)
      SQL
    )
  end

  it "Creates indexes for table" do
    index = Sql::Index.new(Schema.tables[:users], [:name, :email], unique: true)

    Expression::CreateIndex.new(index).accept(Expression::Generator.new).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      CREATE UNIQUE INDEX idx_name_emai ON users (name, email)
      SQL
    )
  end
end
