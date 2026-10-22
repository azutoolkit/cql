require "../spec_helper"

describe "Query inspection" do
  query = -> { Northwind.query.from(:customers).select(:name).where(city: "Tulum").limit(5) }

  describe "#to_sql(for:)" do
    it "renders for another dialect without a connection" do
      query.call.to_sql(for: CQL::Adapter::Postgres).should eq(
        {"SELECT customers.name FROM customers WHERE customers.city = $1 LIMIT $2", ["Tulum", 5] of DB::Any})
      query.call.to_sql(for: CQL::Adapter::MySql)[0].should end_with("customers.city = ? LIMIT ?")
    end

    it "quotes identifiers when the schema opted in" do
      schema = CQL::Schema.define(:quoted, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("inspection_quoted.db"), quote_identifiers: true) do
        table :order do
          primary :id, Int32
        end
      end

      schema.query.from(:order).to_sql(for: CQL::Adapter::Postgres)[0].should contain(%("order"."id"))
    end

    it "works for compound queries" do
      other = Northwind.query.from(:users).select(:name)
      query.call.union(other).to_sql(for: CQL::Adapter::Postgres)[0].should contain("LIMIT $2) UNION SELECT users.name")
    end
  end

  describe "#explain" do
    before_each { UserDB.users.create! }
    after_each { UserDB.users.drop! }

    it "returns the SQLite query plan as text" do
      plan = UserDB.query.from(:users).select(:name).where(name: "ada").explain

      plan.should be_a(String)
      plan.should contain("users")
    end

    it "binds the query's parameters" do
      UserDB.query.from(:users).where(name: "ada").where(age: 3).explain.should_not be_empty
    end

    it "works for compound queries" do
      names = UserDB.query.from(:users).select(:name)
      names.union(names).explain.should contain("users")
    end

    it "is not recorded as an executed query" do
      UserDB.query.from(:users).where(name: "ada").explain
      CQL::Performance.monitor.metrics.to_json.should_not contain("EXPLAIN")
    end

    it "rejects ANALYZE on SQLite with a clear error" do
      expect_raises(CQL::DialectError, /SQLite does not support EXPLAIN ANALYZE/) do
        UserDB.query.from(:users).explain(analyze: true)
      end
    end
  end

  describe "dialect EXPLAIN statements" do
    it "uses each dialect's syntax" do
      CQL::Adapter::Postgres.dialect.explain("SELECT 1", false).should eq("EXPLAIN SELECT 1")
      CQL::Adapter::Postgres.dialect.explain("SELECT 1", true).should eq("EXPLAIN ANALYZE SELECT 1")
      CQL::Adapter::MySql.dialect.explain("SELECT 1", true).should eq("EXPLAIN ANALYZE SELECT 1")
      CQL::Adapter::SQLite.dialect.explain("SELECT 1", false).should eq("EXPLAIN QUERY PLAN SELECT 1")
    end

    it "keeps the readable column of each plan row" do
      CQL::Adapter::Postgres.dialect.format_plan_row(["Seq Scan on t"]).should eq("Seq Scan on t")
      CQL::Adapter::SQLite.dialect.format_plan_row(["2", "0", "0", "SCAN t"]).should eq("SCAN t")
      CQL::Adapter::MySql.dialect.format_plan_row(["1", "SIMPLE", "t"]).should eq("1 | SIMPLE | t")
    end
  end
end
