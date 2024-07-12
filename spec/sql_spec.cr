require "./spec_helper"

describe Sql do


  it "complex query" do
    generator = Sql::Generator.new
    select_query_complex = Sql.select(id: "ulid", name: "full_name")
      .from("employees")
      .where {
        (salary < "5000")
          .and(name.not_null)
          .or(name == "'Jose'")
          .or(department.in ["'peo'", "'accounting'"])
      }.order_by("name")
      .order_by("age", "DESC")
      .build

    select_query_complex.accept(generator).should eq(
      "SELECT id, name FROM employees WHERE (salary < 5000 AND name IS NOT NULL OR name = 'Jose' OR department IN ('peo', 'accounting')) ORDER BY name ASC, age DESC"
    )
  end

  it "handles subqueries" do
    generator = Sql::Generator.new
    sub_query = Sql.select("id")
      .from("departments", as: "d")
      .where {
        salary < "5000"
      }

    select_query = Sql.select("id", "name")
      .from("employees", as: "e")
      .where {
        department.in(sub_query)
      }.build

    select_query.accept(generator).should eq(
      "SELECT id, name FROM employees as d WHERE department IN (SELECT id, name FROM employees WHERE salary < 5000)"
    )
  end

  it "Select query with GROUP BY clause" do
    generator = Sql::Generator.new
    select_query = Sql.select("department", "COUNT(*)")
      .from("employees")
      .group_by("department")
      .order_by("department")
      .build

    select_query.accept(generator).should eq(
      "SELECT department, COUNT(*) FROM employees GROUP BY department ORDER BY department ASC"
    )
  end
end
