require "../spec_helper"

# Regression: a nested query used to clear the parameters already collected
# by the enclosing query, dropping bound values and restarting `$n` numbering.
describe "Nested query parameter binding" do
  subquery = -> { Northwind.query.from(:orders).select(:customer_id).where { orders.total > 1000 } }

  it "keeps outer parameters when a subquery follows them (positional placeholders)" do
    sql, params = Northwind.query
      .from(:customers)
      .select(:name)
      .where(city: "Tulum")
      .where { customers.id.in(subquery.call) }
      .to_sql

    params.should eq(["Tulum", 1000] of DB::Any)
    sql.should contain("customers.city = ?")
    sql.should contain("IN (SELECT orders.customer_id FROM orders WHERE orders.total > ?)")
  end

  it "keeps outer parameters when a subquery precedes them" do
    _, params = Northwind.query
      .from(:customers)
      .select(:name)
      .where { customers.id.in(subquery.call) }
      .where(city: "Tulum")
      .to_sql

    params.should eq([1000, "Tulum"] of DB::Any)
  end

  it "continues $n numbering across the subquery on PostgreSQL" do
    generator = Expression::Generator.new(CQL::Adapter::Postgres)
    sql, params = Northwind.query
      .from(:customers)
      .select(:name)
      .where(city: "Tulum")
      .where { customers.id.in(subquery.call) }
      .to_sql(generator)

    params.should eq(["Tulum", 1000] of DB::Any)
    sql.should contain("customers.city = $1")
    sql.should contain("orders.total > $2")
  end

  it "keeps outer parameters for EXISTS subqueries" do
    _, params = Northwind.query
      .from(:customers)
      .select(:name)
      .where(city: "Tulum")
      .where { exists?(subquery.call) }
      .to_sql

    params.should eq(["Tulum", 1000] of DB::Any)
  end

  it "does not leak parameters between consecutive top-level generations" do
    generator = Expression::Generator.new(CQL::Adapter::Postgres)
    query = Northwind.query.from(:customers).select(:name).where(city: "Tulum")
    first = query.to_sql(generator)
    second = query.to_sql(generator)

    second.should eq(first)
    second[1].should eq(["Tulum"] of DB::Any)
  end
end

describe "Nested query parameter binding in UPDATE, DELETE and INSERT ... SELECT" do
  subquery = -> { Northwind.query.from(:orders).select(:customer_id).where { orders.total > 1000 } }

  it "keeps SET values when an UPDATE WHERE contains a subquery" do
    sql, params = Northwind.update.table(:customers).set(city: "X")
      .where { customers.id.in(subquery.call) }.to_sql

    params.should eq(["X", 1000] of DB::Any)
    sql.should contain("SET city = ?")
  end

  it "keeps outer WHERE values and numbering in a DELETE with a subquery (PostgreSQL)" do
    generator = Expression::Generator.new(CQL::Adapter::Postgres)
    sql, params = Northwind.delete.from(:customers).where(city: "Z")
      .where { customers.id.in(subquery.call) }.to_sql(generator)

    params.should eq(["Z", 1000] of DB::Any)
    sql.should contain("customers.city = $1")
    sql.should contain("orders.total > $2")
  end

  it "numbers an UPDATE with a subquery consistently (PostgreSQL)" do
    generator = Expression::Generator.new(CQL::Adapter::Postgres)
    sql, params = Northwind.update.table(:customers).set(city: "X")
      .where { customers.id.in(subquery.call) }.to_sql(generator)

    params.should eq(["X", 1000] of DB::Any)
    sql.should contain("SET city = $1")
    sql.should contain("orders.total > $2")
  end
end
