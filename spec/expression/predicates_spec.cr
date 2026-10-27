require "../spec_helper"

describe "Additional predicates" do
  pg = -> { Expression::Generator.new(CQL::Adapter::Postgres) }
  mysql = -> { Expression::Generator.new(CQL::Adapter::MySql) }
  base = -> { Northwind.query.from(:customers).select(:name) }

  describe "ILIKE" do
    it "uses ILIKE on PostgreSQL and CockroachDB" do
      base.call.where { customers.name.ilike("ad%") }.to_sql(pg.call).should eq(
        {"SELECT customers.name FROM customers WHERE customers.name ILIKE $1", ["ad%"] of DB::Any})
      base.call.where { customers.name.not_ilike("ad%") }.to_sql(Expression::Generator.new(CQL::Adapter::CockroachDB))[0].should end_with("customers.name NOT ILIKE $1")
    end

    it "falls back to LOWER() comparison elsewhere" do
      sql, params = base.call.where { customers.name.ilike("Ad%") }.to_sql
      sql.should end_with("WHERE LOWER(customers.name) LIKE LOWER(?)")
      params.should eq(["Ad%"] of DB::Any)

      base.call.where { customers.name.not_ilike("x") }.to_sql(mysql.call)[0].should end_with("LOWER(customers.name) NOT LIKE LOWER(?)")
    end

    it "matches regardless of case when executed on SQLite" do
      UserDB.users.create!
      begin
        UserDB.insert.into(:users).values(name: "Ada", email: "a@x.io", age: 1, password: "pw").commit
        UserDB.query.from(:users).select(:name).where { users.name.ilike("aDA") }.all(as: String).should eq(["Ada"])
        UserDB.query.from(:users).select(:name).where { users.name.not_ilike("aDA") }.all(as: String).should be_empty
      ensure
        UserDB.users.drop!
      end
    end
  end

  describe "contains / starts_with / ends_with" do
    it "escapes LIKE wildcards in the bound text and declares ESCAPE '!'" do
      base.call.where { customers.name.contains("50%_off!") }.to_sql.should eq(
        {"SELECT customers.name FROM customers WHERE customers.name LIKE ? ESCAPE '!'", ["%50!%!_off!!%"] of DB::Any})
      base.call.where { customers.name.starts_with("ab") }.to_sql[1].should eq(["ab%"] of DB::Any)
      base.call.where { customers.name.ends_with("ab") }.to_sql[1].should eq(["%ab"] of DB::Any)
    end

    it "emits the same ESCAPE clause on PostgreSQL, CockroachDB and MySQL" do
      base.call.where { (customers.city == "x") & customers.name.contains("a_b") }.to_sql(pg.call).should eq(
        {"SELECT customers.name FROM customers WHERE (customers.city = $1) AND (customers.name LIKE $2 ESCAPE '!')", ["x", "%a!_b%"] of DB::Any})
      base.call.where { customers.name.ends_with("a") }.to_sql(Expression::Generator.new(CQL::Adapter::CockroachDB))[0].should end_with("LIKE $1 ESCAPE '!'")
      base.call.where { customers.name.starts_with("a%") }.to_sql(mysql.call).should eq(
        {"SELECT customers.name FROM customers WHERE customers.name LIKE ? ESCAPE '!'", ["a!%%"] of DB::Any})
    end

    it "matches the text literally when executed on SQLite" do
      UserDB.users.create!
      begin
        ["50% off", "500 off", "a_b", "axb"].each_with_index do |name, i|
          UserDB.insert.into(:users).values(name: name, email: "#{i}@x.io", age: 1, password: "pw").commit
        end
        matching = ->(text : String) { UserDB.query.from(:users).select(:name).where { users.name.contains(text) }.all(as: String) }
        matching.call("50%").should eq(["50% off"])
        matching.call("a_b").should eq(["a_b"])
        matching.call("%").should eq(["50% off"])
        expect_raises(ArgumentError, "NUL") { matching.call("\0y") } # SQLite would end the pattern at the NUL: every row
        expect_raises(ArgumentError, "NUL") { UserDB.query.from(:users).where { users.name.ends_with("\0") } }
      ensure
        UserDB.users.drop!
      end
    end
  end

  describe "NOT" do
    it "negates a condition with not(...) or .not" do
      sql, params = base.call.where { not(customers.city == "Tulum") }.to_sql
      sql.should end_with("WHERE NOT (customers.city = ?)")
      params.should eq(["Tulum"] of DB::Any)

      base.call.where { (customers.id > 1).not }.to_sql[0].should end_with("WHERE NOT (customers.id > ?)")
    end

    it "negates a whole AND / OR group, not just its first operand" do
      sql, _ = base.call.where { ((customers.city == "A") & (customers.id > 1)).not }.to_sql
      sql.should end_with("WHERE NOT ((customers.city = ?) AND (customers.id > ?))")
    end

    it "keeps NOT IN / NOT BETWEEN readable" do
      base.call.where { customers.id.not_in([1, 2]) }.to_sql[0].should end_with("WHERE NOT (customers.id IN (?, ?))")
    end

    it "composes with AND / OR" do
      sql, _ = base.call.where { not(customers.city == "A") & (customers.id > 1) }.to_sql
      sql.should end_with("WHERE (NOT (customers.city = ?)) AND (customers.id > ?)")
    end
  end

  describe "COUNT(DISTINCT)" do
    it "renders DISTINCT inside COUNT, with an alias" do
      Northwind.query.from(:orders).count(:customer_id, distinct: true, as: :buyers).to_sql[0]
        .should eq("SELECT COUNT(DISTINCT orders.customer_id) AS buyers FROM orders")
    end

    it "leaves plain COUNT unchanged" do
      Northwind.query.from(:orders).count(:customer_id).to_sql[0].should eq("SELECT COUNT(orders.customer_id) FROM orders")
    end

    it "counts distinct values when executed" do
      UserDB.users.create!
      begin
        [30, 30, 40].each_with_index do |age, i|
          UserDB.insert.into(:users).values(name: "u#{i}", email: "u#{i}@x.io", age: age, password: "pw").commit
        end
        UserDB.query.from(:users).count(:age, distinct: true, as: :ages).get(as: Int64).should eq(2)
      ensure
        UserDB.users.drop!
      end
    end
  end
end
