require "../spec_helper"

describe "Subquery in FROM" do
  pg = -> { Expression::Generator.new(CQL::Adapter::Postgres) }
  spend = -> { Northwind.query.from(:orders).select(:customer_id).sum(:total, as: :spent).group(:customer_id) }

  it "renders (subquery) AS alias and exposes its columns" do
    sql, params = Northwind.query
      .from(spend.call.where { orders.total > 5 }, as: :t)
      .select(:customer_id, :spent)
      .where { t.spent > 100 }
      .to_sql

    sql.should eq(
      "SELECT t.customer_id, t.spent FROM " \
      "(SELECT orders.customer_id, SUM(orders.total) AS spent FROM orders WHERE orders.total > ? GROUP BY orders.customer_id) AS t " \
      "WHERE t.spent > ?")
    params.should eq([5, 100] of DB::Any)
  end

  it "numbers parameters in text order on PostgreSQL" do
    sql, params = Northwind.query.from(spend.call.where { orders.total > 5 }, as: :t).select(:spent).where { t.spent > 100 }.to_sql(pg.call)

    params.should eq([5, 100] of DB::Any)
    sql.should contain("orders.total > $1")
    sql.should end_with("t.spent > $2")
  end

  it "quotes the alias when identifier quoting is on" do
    sql, _ = Northwind.query.from(spend.call, as: :t).select(:spent)
      .to_sql(Expression::Generator.new(CQL::Adapter::Postgres, quote_identifiers: true))

    sql.should contain(") AS \"t\"")
  end

  it "keeps working after clone" do
    base = Northwind.query.from(spend.call, as: :t).select(:spent)
    base.clone.to_sql.should eq(base.to_sql)
  end

  it "runs against SQLite" do
    UserDB.users.create!
    begin
      [20, 40, 60].each_with_index do |age, i|
        UserDB.insert.into(:users).values(name: "u#{i}", email: "u#{i}@x.io", age: age, password: "pw").commit
      end
      ages = UserDB.query.from(:users).select(:age).where { users.age >= 40 }

      UserDB.query.from(ages, as: :older).select(:age).order(age: :asc).all(as: Int32).should eq([40, 60])
    ensure
      UserDB.users.drop!
    end
  end
end
