require "../spec_helper"

describe "Table and column aliases in the block DSL" do
  it "qualifies columns with the table alias, not the table name" do
    sql, params = Northwind.query
      .from(customers: :c)
      .select(:name)
      .where { c.city == "Tulum" }
      .to_sql

    sql.should contain("WHERE c.city = ?")
    sql.should_not contain("customers.city")
    params.should eq(["Tulum"] of DB::Any)
  end

  it "leaves un-aliased tables qualified by their own name" do
    sql, _ = Northwind.query.from(:customers).select(:name).where { customers.city == "Tulum" }.to_sql

    sql.should contain("WHERE customers.city = ?")
  end

  it "does not mistake a column-level `as:` for a table qualifier" do
    column = CQL::Column(String).new(:nickname, as_name: "alias_x")
    column.expression.should be_a(Expression::TypedColumn(String))
    column.expression("t").alias_name.should eq("t")
  end
end
