require "../spec_helper"

describe "Row locking" do
  pg = -> { Expression::Generator.new(CQL::Adapter::Postgres) }
  mysql = -> { Expression::Generator.new(CQL::Adapter::MySql) }
  cockroach = -> { Expression::Generator.new(CQL::Adapter::CockroachDB) }
  jobs = -> { Northwind.query.from(:orders).select(:id) }

  it "renders FOR UPDATE after LIMIT" do
    sql, params = jobs.call.limit(1).lock.to_sql(pg.call)

    sql.should eq("SELECT orders.id FROM orders LIMIT $1 FOR UPDATE")
    params.should eq([1] of DB::Any)
  end

  it "supports share locks and wait policies" do
    jobs.call.lock(:share).to_sql(pg.call)[0].should end_with("FOR SHARE")
    jobs.call.lock(skip_locked: true).to_sql(pg.call)[0].should end_with("FOR UPDATE SKIP LOCKED")
    jobs.call.lock(:update, nowait: true).to_sql(mysql.call)[0].should end_with("FOR UPDATE NOWAIT")
    jobs.call.lock.to_sql(cockroach.call)[0].should end_with("FOR UPDATE")
  end

  it "keeps parameters in text order" do
    sql, params = jobs.call.where(customer_id: 3).limit(2).lock.to_sql(pg.call)

    sql.should end_with("orders.customer_id = $1 LIMIT $2 FOR UPDATE")
    params.should eq([3, 2] of DB::Any)
  end

  it "is carried by clone" do
    jobs.call.lock.clone.to_sql(pg.call)[0].should end_with("FOR UPDATE")
  end

  it "is rejected on SQLite with a clear error" do
    expect_raises(CQL::DialectError, /SQLite does not support row locking/) { jobs.call.lock.to_sql }
  end

  it "rejects unknown modes and contradictory wait policies" do
    expect_raises(ArgumentError, /Unknown lock mode/) { jobs.call.lock(:exclusive) }
    expect_raises(ArgumentError, /skip_locked or nowait/) { jobs.call.lock(skip_locked: true, nowait: true) }
  end
end

describe "DISTINCT ON" do
  pg = -> { Expression::Generator.new(CQL::Adapter::Postgres) }
  latest = -> { Northwind.query.from(:orders).select(:customer_id, :total).order(customer_id: :asc, total: :desc) }

  it "renders DISTINCT ON (...) for PostgreSQL and CockroachDB" do
    sql, _ = latest.call.distinct_on(:customer_id).to_sql(pg.call)
    sql.should eq("SELECT DISTINCT ON (orders.customer_id) orders.customer_id, orders.total FROM orders ORDER BY orders.customer_id ASC, orders.total DESC")

    latest.call.distinct_on(:customer_id, :total).to_sql(Expression::Generator.new(CQL::Adapter::CockroachDB))[0].should contain("DISTINCT ON (orders.customer_id, orders.total)")
  end

  it "is rejected on MySQL and SQLite with a clear error" do
    expect_raises(CQL::DialectError, /MySQL does not support DISTINCT ON/) { latest.call.distinct_on(:customer_id).to_sql(Expression::Generator.new(CQL::Adapter::MySql)) }
    expect_raises(CQL::DialectError, /SQLite does not support DISTINCT ON/) { latest.call.distinct_on(:customer_id).to_sql }
  end

  it "is carried by clone and quoted when requested" do
    query = latest.call.distinct_on(:customer_id)
    query.clone.to_sql(pg.call)[0].should contain("DISTINCT ON (orders.customer_id)")
    query.to_sql(Expression::Generator.new(CQL::Adapter::Postgres, quote_identifiers: true))[0].should contain("DISTINCT ON (\"orders\".\"customer_id\")")
  end
end

describe "FULL and CROSS joins" do
  it "renders FULL JOIN ... ON" do
    sql, _ = Northwind.query.from(:customers).select(customers: [:name])
      .full(:orders) { |j| j.orders.customer_id.eq(j.customers.id) }.to_sql

    sql.should contain("FULL JOIN orders ON orders.customer_id = customers.id")
  end

  it "renders CROSS JOIN without ON" do
    sql, _ = Northwind.query.from(:customers).select(customers: [:name]).cross(:orders).to_sql
    sql.should contain("FROM customers CROSS JOIN orders")
    sql.should_not contain(" ON ")
  end

  it "rejects FULL JOIN on MySQL" do
    expect_raises(CQL::DialectError, /MySQL does not support FULL JOIN/) do
      Northwind.query.from(:customers).full(:orders) { |j| j.orders.customer_id.eq(j.customers.id) }
        .to_sql(Expression::Generator.new(CQL::Adapter::MySql))
    end
  end
end

describe "DISTINCT with DISTINCT ON, and merge" do
  pg = -> { Expression::Generator.new(CQL::Adapter::Postgres) }
  orders = -> { Northwind.query.from(:orders).select(:customer_id) }

  it "lets DISTINCT ON subsume DISTINCT instead of emitting both" do
    sql, _ = orders.call.distinct.distinct_on(:customer_id).to_sql(pg.call)

    sql.should eq("SELECT DISTINCT ON (orders.customer_id) orders.customer_id FROM orders")
  end

  it "carries a row lock through merge" do
    merged = Northwind.query.from(:orders).select(:id).merge(orders.call.lock(skip_locked: true))
    merged.to_sql(pg.call)[0].should end_with("FOR UPDATE SKIP LOCKED")
  end

  it "keeps the current lock when the other query has none, and carries DISTINCT ON" do
    locked = orders.call.lock
    locked.merge(Northwind.query.from(:orders).select(:id)).to_sql(pg.call)[0].should end_with("FOR UPDATE")

    merged = Northwind.query.from(:orders).select(:id).merge(orders.call.distinct_on(:customer_id))
    merged.to_sql(pg.call)[0].should contain("DISTINCT ON (orders.customer_id)")
  end
end
