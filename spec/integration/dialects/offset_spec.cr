require "../../spec_helper"

# Regression: OFFSET without LIMIT used to be dropped silently.
describe "OFFSET without LIMIT" do
  query = -> { Northwind.query.from(:customers).select(:name).offset(5) }

  it "emits a bare OFFSET on PostgreSQL" do
    sql, params = query.call.to_sql(Expression::Generator.new(CQL::Adapter::Postgres))

    sql.should eq("SELECT customers.name FROM customers OFFSET $1")
    params.should eq([5] of DB::Any)
  end

  it "pairs OFFSET with LIMIT -1 on SQLite" do
    sql, params = query.call.to_sql(Expression::Generator.new(CQL::Adapter::SQLite))

    sql.should eq("SELECT customers.name FROM customers LIMIT -1 OFFSET ?")
    params.should eq([5] of DB::Any)
  end

  it "pairs OFFSET with the maximum LIMIT on MySQL" do
    sql, params = query.call.to_sql(Expression::Generator.new(CQL::Adapter::MySql))

    sql.should eq("SELECT customers.name FROM customers LIMIT 18446744073709551615 OFFSET ?")
    params.should eq([5] of DB::Any)
  end

  it "still emits LIMIT and OFFSET together" do
    sql, params = Northwind.query.from(:customers).select(:name).limit(10).offset(5).to_sql
    sql.should eq("SELECT customers.name FROM customers LIMIT ? OFFSET ?")
    params.should eq([10, 5] of DB::Any)
  end

  it "executes against SQLite and skips the leading rows" do
    UserDB.users.create!
    begin
      3.times do |i|
        UserDB.insert.into(:users).values(name: "u#{i}", email: "u#{i}@example.com", age: 20 + i, password: "secret").commit
      end

      all = UserDB.query.from(:users).select(:id).order(id: :asc).all(as: Int32)
      skipped = UserDB.query.from(:users).select(:id).order(id: :asc).offset(1).all(as: Int32)

      all.size.should eq(3)
      skipped.should eq(all[1..])
    ensure
      UserDB.users.drop!
    end
  end
end
