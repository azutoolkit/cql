require "../../spec_helper"

describe "Bulk INSERT generation" do
  rows = [
    {:name => "Ada", :email => "ada@example.com"} of Symbol => DB::Any,
    {:name => "Grace", :email => "grace@example.com"} of Symbol => DB::Any,
    {:name => "Linus", :email => "linus@example.com"} of Symbol => DB::Any,
  ]

  it "numbers every row's placeholders distinctly on PostgreSQL" do
    generator = Expression::Generator.new(CQL::Adapter::Postgres)
    sql, params = Northwind.insert.into(:users).values(rows).to_sql(generator)

    sql.should eq("INSERT INTO users (name, email) VALUES ($1, $2), ($3, $4), ($5, $6)")
    params.should eq(["Ada", "ada@example.com", "Grace", "grace@example.com", "Linus", "linus@example.com"] of DB::Any)
  end

  it "generates positional placeholders for SQLite" do
    sql, params = Northwind.insert.into(:users).values(rows).to_sql

    sql.should eq("INSERT INTO users (name, email) VALUES (?, ?), (?, ?), (?, ?)")
    params.size.should eq(6)
  end

  it "aligns values by column name when rows list keys in a different order" do
    reordered = [
      {:name => "Ada", :email => "ada@example.com"} of Symbol => DB::Any,
      {:email => "grace@example.com", :name => "Grace"} of Symbol => DB::Any,
    ]
    _, params = Northwind.insert.into(:users).values(reordered).to_sql

    params.should eq(["Ada", "ada@example.com", "Grace", "grace@example.com"] of DB::Any)
  end

  it "rejects rows whose columns differ from the first row instead of misaligning values" do
    ragged = [
      {:name => "Ada", :email => "ada@example.com"} of Symbol => DB::Any,
      {:name => "Grace"} of Symbol => DB::Any,
    ]

    expect_raises(ArgumentError, /same columns/) do
      Northwind.insert.into(:users).values(ragged)
    end
  end
end
