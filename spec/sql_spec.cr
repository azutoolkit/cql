require "./spec_helper"

describe Sql do
  generator = Sql::Generator.new

  it "select data from a database" do
    select_query = Sql.select("CustomerName", "City")
      .from("Customers")
      .build

    select_query.accept(generator).should eq("SELECT Customers.CustomerName, Customers.City FROM Customers")
  end

  it "SELECT DISTINCT Statement" do
    select_query = Sql.select("City").distinct
      .from("Customers")
      .build

    select_query.accept(generator).should eq("SELECT DISTINCT Customers.City FROM Customers")
  end

  it "WHERE Clause" do
    select_query = Sql.select("CustomerName", "City")
      .from("Customers")
      .where {
        city == "'London'"
      }.build

    select_query.accept(generator).should eq("SELECT Customers.CustomerName, Customers.City FROM Customers WHERE (city = 'London')")
  end

  it "WHERE complex query" do
    select_query_complex = Sql.select(id: "ulid", name: "full_name")
      .from("employees")
      .where {
        (salary < 5000)
          .and(name.not_null)
          .or(name == "'Jose'")
          .or(department.in ["'peo'", "'accounting'"])
      }.order_by("name")
      .order_by("age", "DESC")
      .build

    select_query_complex.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT employees.id, employees.name
      FROM employees
      WHERE (salary < 5000
      AND name IS NOT NULL
      OR name = 'Jose'
      OR department IN ('peo', 'accounting'))
      ORDER BY name ASC, age DESC
      SQL
    )
  end

  it "ORDER BY" do
    select_query = Sql.select("CustomerName", "City")
      .from("Customers")
      .order_by("City")
      .build

    select_query.accept(generator).should eq("SELECT Customers.CustomerName, Customers.City FROM Customers ORDER BY City ASC")
  end

  it "SQL AND Operator" do
    select_query = Sql.select("CustomerName", "City")
      .from("Customers")
      .where {
        (city == "'London'").and(city == "'Berlin'")
      }.build

    select_query.accept(generator).should eq("SELECT Customers.CustomerName, Customers.City FROM Customers WHERE (city = 'London' AND city = 'Berlin')")
  end

  it "like operator" do
    select_query = Sql.select("CustomerName", "City")
      .from("Customers")
      .where {
        city.like("a%")
      }.build

    select_query.accept(generator).should eq("SELECT Customers.CustomerName, Customers.City FROM Customers WHERE ((city LIKE 'a%'))")
  end

  it "NOT Operator" do
    select_query = Sql.select("CustomerName", "City")
      .from("Customers")
      .where {
        not(city == "hello")
      }.build

    select_query.accept(generator).should eq("SELECT Customers.CustomerName, Customers.City FROM Customers WHERE (NOT city = hello)")
  end

  it "NOT LIKE Operator" do
    select_query = Sql.select("CustomerName", "City")
      .from("Customers")
      .where {
        city.not_like("a%")
      }.build

    select_query.accept(generator).should eq("SELECT Customers.CustomerName, Customers.City FROM Customers WHERE ((city NOT LIKE 'a%'))")
  end

  it "IS NULL Operator" do
    select_query = Sql.select("CustomerName", "City")
      .from("Customers")
      .where {
        city.null
      }.build

    select_query.accept(generator).should eq("SELECT Customers.CustomerName, Customers.City FROM Customers WHERE (city IS NULL)")
  end

  it "IS NOT NULL Operator" do
    select_query = Sql.select("CustomerName", "City")
      .from("Customers")
      .where {
        city.not_null
      }.build

    select_query.accept(generator).should eq("SELECT Customers.CustomerName, Customers.City FROM Customers WHERE (city IS NOT NULL)")
  end

  it "SELECT TOP Clause" do
    select_query = Sql.select("CustomerName", "City")
      .from("Customers")
      .top(3)
      .build

    select_query.accept(generator).should eq("SELECT TOP 3 Customers.CustomerName, Customers.City FROM Customers")
  end

  it "EXISTS Operator" do
    sub_query =
      select_query = Sql.select("id", "name")
        .from("employees")
        .where {
          exists(Sql.select("id")
            .from("departments")
            .where {
              salary < 5000
            })
        }.build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT employees.id, employees.name
      FROM employees
      WHERE (EXISTS (SELECT departments.id FROM departments WHERE (salary < 5000)))
      SQL
    )
  end

  it "HAVING Clause" do
    select_query = Sql.select("department", "COUNT(*)")
      .from("employees")
      .group_by("department")
      .having {
        department.count > 1
      }.build

    select_query.accept(generator).should eq(
      "SELECT employees.department, employees.COUNT(*) FROM employees GROUP BY department HAVING COUNT(department) > 1"
    )
  end

  it "handles subqueries" do
    sub_query = Sql.select("id")
      .from("departments", as: "d")
      .where {
        salary < 5000
      }

    select_query = Sql.select("id", "name")
      .from("employees", as: "e")
      .where {
        department.in(sub_query)
      }.build

    select_query.accept(generator).should eq(
      <<-SQL.gsub(/\n/, " ").strip
      SELECT e.id, e.name
      FROM employees AS e
      WHERE (department IN (SELECT d.id FROM departments AS d WHERE (salary < 5000)))
      SQL
    )
  end

  it "Select query with GROUP BY clause" do
    select_query = Sql.select("department", "COUNT(*)")
      .from("employees")
      .group_by("department")
      .order_by("department")
      .build

    select_query.accept(generator).should eq(
      "SELECT employees.department, employees.COUNT(*) FROM employees GROUP BY department ORDER BY department ASC"
    )
  end

  it "builds JOINS" do
    select_query = Sql
      .select("name", "name")
      .from("employees", as: "e")
      .inner_join("departments", as: "d") do
        department_id == "d.id"
      end.build

    select_query.accept(generator).should eq(
      "SELECT e.name, d.name FROM employees AS e INNER JOIN departments AS d ON e.department_id = d.id"
    )
  end
end
