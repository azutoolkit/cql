require "../spec_helper"

describe "CTE and derived-table scoping" do
  pg = -> { Expression::Generator.new(CQL::Adapter::Postgres) }
  mysql = -> { Expression::Generator.new(CQL::Adapter::MySql, quote_identifiers: true) }
  spend = -> { Northwind.query.from(:orders).select(:customer_id).sum(:total, as: :spent).group(:customer_id) }

  describe "set operations over queries with CTEs" do
    it "groups an operand that declares CTEs" do
      with_cte = Northwind.query.with(:t, spend.call).from(:t).select(:customer_id)
      plain = Northwind.query.from(:customers).select(:id)

      plain.union(with_cte).to_sql(pg.call)[0].should contain("UNION (WITH t AS (")
      with_cte.union(plain).to_sql(pg.call)[0].should start_with("(WITH t AS (")
      plain.union(with_cte).to_sql[0].should contain("UNION SELECT * FROM (WITH t AS (")
    end
  end

  describe "implicit select list" do
    before_each do
      UserDB.users.create!
      UserDB.insert.into(:users).values(name: "ada", email: "a@x.io", age: 40, password: "pw").commit
    end
    after_each { UserDB.users.drop! }

    it "selects only the real columns of a CTE" do
      ages = UserDB.query.from(:users).select(:name, :age)
      query = UserDB.query.with(:a, ages).from(:a)

      query.to_sql[0].should contain("SELECT a.name, a.age FROM a")
      query.all(as: {String, Int32}).should eq([{"ada", 40}])
    end

    it "selects only the real columns of a FROM subquery" do
      ages = UserDB.query.from(:users).select(:name, :age)
      query = UserDB.query.from(ages, as: :a)

      query.to_sql[0].should start_with("SELECT a.name, a.age FROM (SELECT")
      query.all(as: {String, Int32}).should eq([{"ada", 40}])
    end
  end

  describe "resetting and carrying state" do
    it "forgets a FROM subquery when from is called again" do
      query = Northwind.query.from(spend.call, as: :orders).from(:orders).select(:total)

      query.to_sql[0].should eq("SELECT orders.total FROM orders")
      query.clone.to_sql[0].should eq("SELECT orders.total FROM orders")
    end

    it "carries CTEs through merge" do
      cte_query = Northwind.query.with(:t, spend.call).from(:t).select(:customer_id)
      base = Northwind.query.from(:customers).select(:name)
      base.merge(cte_query).to_sql[0].should start_with("WITH t AS (")
    end

    it "carries a FROM subquery through merge" do
      derived = Northwind.query.from(spend.call, as: :t).select(:customer_id)
      Northwind.query.from(:customers).select(:name).merge(derived).to_sql[0].should contain(") AS t")
    end

    it "rejects merging two different CTEs with the same name" do
      a = Northwind.query.with(:t, spend.call).from(:t)
      b = Northwind.query.with(:t, spend.call).from(:t)

      expect_raises(ArgumentError, /Merge conflict: CTE t/) { a.merge(b) }
    end
  end

  describe "naming and visibility" do
    it "rejects duplicate CTE names" do
      expect_raises(ArgumentError, /already declared/) do
        Northwind.query.with(:t, spend.call).with(:t, spend.call)
      end
    end

    it "lets a later CTE read an earlier one" do
      sql, _ = Northwind.query
        .with(:totals, spend.call)
        .with(:big) { |scope| scope.from(:totals).select(:customer_id).where { totals.spent > 100 } }
        .from(:big).select(:customer_id)
        .to_sql

      sql.should start_with("WITH totals AS (")
      sql.should contain("), big AS (SELECT totals.customer_id FROM totals WHERE totals.spent > ?) SELECT big.customer_id FROM big")
    end

    it "lets a subquery see the enclosing CTEs through nested" do
      outer = Northwind.query.with(:totals, spend.call)
      sql, params = outer.from(:customers).select(:name)
        .where { exists?(outer.nested.from(:totals).select(:customer_id).where { totals.spent > 5 }) }
        .to_sql

      sql.should contain("EXISTS (SELECT totals.customer_id FROM totals WHERE totals.spent > ?)")
      params.should eq([5] of DB::Any)
    end
  end

  describe "recursive CTEs" do
    nodes = -> { Northwind.query.from(:customers).select(:id, :name) }
    walk = ->(all : Bool) do
      Northwind.query.with_recursive(:r, nodes.call.where(id: 1), all: all) do |step|
        step.from(:r).join(:customers) { |j| j.customers.id.eq(j.r.id) }.select(customers: [:id, :name])
      end.from(:r).select(:name).where { r.id < 9 }
    end

    it "renders UNION ALL or UNION for the step" do
      walk.call(true).to_sql[0].should contain(" UNION ALL SELECT ")
      walk.call(false).to_sql[0].should contain(" UNION SELECT ")
    end

    it "numbers parameters in order on PostgreSQL" do
      sql, params = walk.call(true).to_sql(pg.call)

      sql.should start_with("WITH RECURSIVE r AS (SELECT customers.id, customers.name FROM customers WHERE customers.id = $1 UNION ALL")
      sql.should end_with("WHERE r.id < $2")
      params.should eq([1, 9] of DB::Any)
    end

    it "quotes names on MySQL" do
      walk.call(true).to_sql(mysql.call)[0].should start_with("WITH RECURSIVE `r` AS (SELECT `customers`.`id`")
    end

    it "rejects a step with ORDER BY, LIMIT or its own CTEs" do
      expect_raises(ArgumentError, /recursive step/) do
        Northwind.query.with_recursive(:r, nodes.call) { |step| step.from(:r).select(:id, :name).limit(1) }
      end
    end
  end
end
