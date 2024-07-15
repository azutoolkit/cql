require "./spec_helper"

describe Sql do
  generator = Expression::Generator.new
  schema = Sql::Schema.new(:northwind)

  schema.table :customers do
    primary_key :customer_id, Int64, auto_increment: true
    column :name, String
    column :city, String
  end

  schema.table :users do
    primary_key :id, Int64, auto_increment: true
    column :name, String
    column :email, String
  end

  schema.table :address do
    primary_key :id, Int64, auto_increment: true
    column :user_id, Int64, null: false
    column :street, String
    column :city, String
    column :zip, String
  end

  q = Sql::Query.new(schema)

  it "selects all columns from tables" do
    select_query = q
      .from(:customers, :users)
      .build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.customer_id, customers.name, customers.city, users.id, users.name, users.email
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
      .where do
        name.eq("'Tulum'") &
          city.eq("'Kantenah'") &
          city.not_in(["'Cancun'", "'Playa del Carmen'"])
      end.build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT customers.name, customers.city
      FROM customers
      WHERE (customers.name = 'Tulum' AND customers.city = 'Kantenah')
      SQL
    )
  end

  # it "WHERE complex query" do
  #   select_query_complex = Sql.select(id: "ulid", name: "full_name")
  #     .from("employees")
  #     .where {
  #       (salary < 5000)
  #         .and(name.not_null)
  #         .or(name == "'Jose'")
  #         .or(department.in ["'peo'", "'accounting'"])
  #     }.order_by("name")
  #     .order_by("age", "DESC")
  #     .build

  #   select_query_complex.accept(generator).should eq(
  #     <<-SQL.gsub(/\n/, " ").strip
  #     SELECT employees.id, employees.name
  #     FROM employees
  #     WHERE (salary < 5000
  #     AND name IS NOT NULL
  #     OR name = 'Jose'
  #     OR department IN ('peo', 'accounting'))
  #     ORDER BY name ASC, age DESC
  #     SQL
  #   )
  # end

  # it "ORDER BY" do
  #   select_query = Sql.select("CustomerName", "City")
  #     .from("Customers")
  #     .order_by("City")
  #     .build

  #   select_query.accept(generator).should eq(
  #     <<-SQL.gsub(/\n/, " ").strip
  #     SELECT Customers.CustomerName, Customers.City FROM Customers ORDER BY City ASC
  #     SQL
  #   )
  # end

  # it "SQL AND Operator" do
  #   select_query = Sql.select("CustomerName", "City")
  #     .from("Customers")
  #     .where {
  #       (city == "'London'").and(city == "'Berlin'")
  #     }.build

  #   select_query.accept(generator).should eq(
  #     <<-SQL.gsub(/\n/, " ").strip
  #     SELECT Customers.CustomerName, Customers.City
  #     FROM Customers
  #     WHERE (city = 'London' AND city = 'Berlin')
  #     SQL
  #   )
  # end

  # it "like operator" do
  #   select_query = Sql.select("CustomerName", "City")
  #     .from("Customers")
  #     .where {
  #       city.like("a%")
  #     }.build

  #   select_query.accept(generator).should eq(
  #     <<-SQL.gsub(/\n/, " ").strip
  #     SELECT Customers.CustomerName, Customers.City
  #     FROM Customers
  #     WHERE ((city LIKE 'a%'))
  #     SQL
  #   )
  # end

  # it "NOT Operator" do
  #   select_query = Sql.select("CustomerName", "City")
  #     .from("Customers")
  #     .where {
  #       not(city == "hello")
  #     }.build

  #   select_query.accept(generator).should eq(
  #     <<-SQL.gsub(/\n/, " ").strip
  #     SELECT Customers.CustomerName, Customers.City FROM Customers WHERE (NOT city = hello)
  #     SQL
  #   )
  # end

  # it "NOT LIKE Operator" do
  #   select_query = Sql.select("CustomerName", "City")
  #     .from("Customers")
  #     .where {
  #       city.not_like("a%")
  #     }.build

  #   select_query.accept(generator).should eq(
  #     <<-SQL.gsub(/\n/, " ").strip
  #     SELECT Customers.CustomerName, Customers.City FROM Customers WHERE ((city NOT LIKE 'a%'))
  #     SQL
  #   )
  # end

  # it "IS NULL Operator" do
  #   select_query = Sql.select("CustomerName", "City")
  #     .from("Customers")
  #     .where {
  #       city.null
  #     }.build

  #   select_query.accept(generator).should eq(
  #     <<-SQL.gsub(/\n/, " ").strip
  #     SELECT Customers.CustomerName, Customers.City
  #     FROM Customers
  #     WHERE (city IS NULL)
  #     SQL
  #   )
  # end

  # it "IS NOT NULL Operator" do
  #   select_query = Sql.select("CustomerName", "City")
  #     .from("Customers")
  #     .where {
  #       city.not_null
  #     }.build

  #   select_query.accept(generator).should eq(
  #     <<-SQL.gsub(/\n/, " ").strip
  #     SELECT Customers.CustomerName, Customers.City
  #     FROM Customers
  #     WHERE (city IS NOT NULL)
  #     SQL
  #   )
  # end

  # it "SELECT TOP Clause" do
  #   select_query = Sql.select("CustomerName", "City")
  #     .from("Customers")
  #     .top(3)
  #     .build

  #   select_query.accept(generator).should eq(
  #     <<-SQL.gsub(/\n/, " ").strip
  #     SELECT TOP 3 Customers.CustomerName, Customers.City
  #     FROM Customers
  #     SQL
  #   )
  # end

  # it "EXISTS Operator" do
  #   select_query = Sql.select("id", "name")
  #     .from("employees")
  #     .where {
  #       exists(Sql.select("id")
  #         .from("departments")
  #         .where {
  #           salary < 5000
  #         })
  #     }.build

  #   select_query.accept(generator).should eq(
  #     <<-SQL.gsub(/\n/, " ").strip
  #     SELECT employees.id, employees.name
  #     FROM employees
  #     WHERE (EXISTS (SELECT departments.id FROM departments WHERE (salary < 5000)))
  #     SQL
  #   )
  # end

  # it "HAVING Clause" do
  #   select_query = Sql.select("department", "COUNT(*)")
  #     .from("employees")
  #     .group_by("department")
  #     .having {
  #       department.count > 1 | department.max.==(10)
  #     }.build

  #   select_query.accept(generator).should eq(
  #     <<-SQL.gsub(/\n/, " ").strip
  #     SELECT employees.department, employees.COUNT(*)
  #     FROM employees
  #     GROUP BY department HAVING COUNT(department) > 1
  #     SQL
  #   )
  # end

  # it "handles subqueries" do
  #   sub_query = Sql.select("id")
  #     .from("departments", as: "d")
  #     .where {
  #       salary < 5000
  #     }

  #   select_query = Sql.select("id", "name")
  #     .from("employees", as: "e")
  #     .where {
  #       department.in(sub_query)
  #     }.build

  #   select_query.accept(generator).should eq(
  #     <<-SQL.gsub(/\n/, " ").strip
  #     SELECT e.id, e.name
  #     FROM employees AS e
  #     WHERE (department IN (SELECT d.id FROM departments AS d WHERE (salary < 5000)))
  #     SQL
  #   )
  # end

  # it "Select query with GROUP BY clause" do
  #   select_query = Sql
  #     .select("department", "COUNT(*)")
  #     .from("employees")
  #     .group_by("department")
  #     .order_by("department")
  #     .build

  #   select_query.accept(generator).should eq(
  #     <<-SQL.gsub(/\n/, " ").strip
  #     SELECT employees.department, employees.COUNT(*)
  #     FROM employees
  #     GROUP BY department
  #     ORDER BY department ASC
  #     SQL
  #   )
  # end

  # it "builds JOINS" do
  #   select_query = Sql
  #     .select("name", "d.name")
  #     .from("employees", as: "e")
  #     .inner_join("departments", as: "d") do
  #       department_id == "d.id"
  #     end.build

  #   select_query.accept(generator).should eq(
  #     <<-SQL.gsub(/\n/, " ").strip
  #     SELECT e.name, d.name
  #     FROM employees AS e
  #     INNER JOIN departments AS d ON e.department_id = d.id
  #     SQL
  #   )
  # end
end
