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

  it "rejects a later row with an extra or a different column" do
    first = {:name => "Ada", :email => "ada@example.com"} of Symbol => DB::Any
    extra = {:name => "Grace", :email => "g@example.com", :id => 2} of Symbol => DB::Any
    swapped = {:name => "Grace", :id => 2} of Symbol => DB::Any

    expect_raises(ArgumentError, /same columns/) { Northwind.insert.into(:users).values([first, extra]) }
    expect_raises(ArgumentError, /same columns/) { Northwind.insert.into(:users).values([first, swapped]) }
  end

  it "keeps no partial values from a rejected later row" do
    insert = Northwind.insert.into(:users).values(name: "Ada", email: "ada@example.com")

    expect_raises(ArgumentError) { insert.values(name: "Bad", id: 9) }
    _, params = insert.values(name: "Grace", email: "g@example.com").to_sql

    params.should eq(["Ada", "ada@example.com", "Grace", "g@example.com"] of DB::Any)
  end

  it "stays usable after a row with an unknown column is rejected" do
    insert = Northwind.insert.into(:users)

    expect_raises(Exception) { insert.values(name: "a", nope: 1) }
    sql, params = insert.values(name: "a", email: "a@example.com").to_sql

    sql.should eq("INSERT INTO users (name, email) VALUES (?, ?)")
    params.should eq(["a", "a@example.com"] of DB::Any)
  end
end
