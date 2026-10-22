require "../spec_helper"

describe "Common table expressions" do
  pg = -> { Expression::Generator.new(CQL::Adapter::Postgres) }
  spend = -> { Northwind.query.from(:orders).select(:customer_id).sum(:total, as: :spent).group(:customer_id) }

  it "renders WITH name AS (...) and lets the main query use the CTE like a table" do
    sql, params = Northwind.query
      .with(:totals, spend.call)
      .from(:totals).select(:customer_id, :spent)
      .where { totals.spent > 100 }
      .to_sql

    sql.should eq(
      "WITH totals AS (SELECT orders.customer_id, SUM(orders.total) AS spent FROM orders GROUP BY orders.customer_id) " \
      "SELECT totals.customer_id, totals.spent FROM totals WHERE totals.spent > ?")
    params.should eq([100] of DB::Any)
  end

  it "numbers parameters in text order on PostgreSQL" do
    cte = spend.call.where { orders.total > 5 }
    sql, params = Northwind.query.with(:totals, cte).from(:totals).select(:spent).where { totals.spent > 100 }.to_sql(pg.call)

    params.should eq([5, 100] of DB::Any)
    sql.should contain("orders.total > $1")
    sql.should end_with("totals.spent > $2")
  end

  it "supports several CTEs and a CTE that reads another" do
    big = Northwind.query.with(:totals, spend.call).from(:totals).select(:customer_id)
    sql, _ = Northwind.query.with(:totals, spend.call).with(:big, big).from(:big).select(:customer_id).to_sql

    sql.should start_with("WITH totals AS (")
    sql.should contain("), big AS (WITH totals AS (")
    sql.should end_with("SELECT big.customer_id FROM big")
  end

  it "joins a CTE to a real table using an explicit condition" do
    sql, _ = Northwind.query
      .with(:totals, spend.call)
      .from(:customers)
      .join(:totals) { |j| j.totals.customer_id.eq(j.customers.id) }
      .select(customers: [:name], totals: [:spent])
      .to_sql

    sql.should contain("INNER JOIN totals ON totals.customer_id = customers.id")
    sql.should contain("SELECT customers.name, totals.spent FROM customers")
  end

  it "quotes the CTE name when identifier quoting is on" do
    sql, _ = Northwind.query.with(:totals, spend.call).from(:totals).select(:spent)
      .to_sql(Expression::Generator.new(CQL::Adapter::Postgres, quote_identifiers: true))

    sql.should start_with(%(WITH "totals" AS ))
  end

  it "does not change the original query when cloned" do
    base = Northwind.query.with(:totals, spend.call)
    base.clone.should_not be(base)
    base.clone.from(:totals).select(:spent).to_sql[0].should start_with("WITH totals AS")
  end

  it "rejects unknown columns on a CTE" do
    expect_raises(ArgumentError, /not found/) do
      Northwind.query.with(:totals, spend.call).from(:totals).select(:nope).to_sql
    end
  end

  it "rejects a CTE name that is not a plain identifier" do
    expect_raises(ArgumentError, /Invalid CTE name/) { Northwind.query.with(:"x; DROP TABLE y", spend.call) }
  end

  describe "executing against SQLite" do
    before_each do
      UserDB.users.create!
      [{"ada", 20}, {"grace", 40}, {"linus", 60}].each do |name, age|
        UserDB.insert.into(:users).values(name: name, email: "#{name}@x.io", age: age, password: "pw").commit
      end
    end
    after_each { UserDB.users.drop! }

    it "runs a CTE query" do
      adults = UserDB.query.from(:users).select(:name, :age).where { users.age >= 40 }

      UserDB.query.with(:adults, adults).from(:adults).select(:name).order(name: :asc)
        .all(as: String).should eq(%w[grace linus])
    end

    it "runs a CTE with an aggregate column" do
      stats = UserDB.query.from(:users).avg(:age, as: :mean)

      UserDB.query.with(:stats, stats).from(:stats).select(:mean).get(as: Float64).should eq(40.0)
    end
  end

  describe "WITH RECURSIVE" do
    tree = CQL::Schema.define(:cte_tree, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("cte_tree.db")) do
      table :nodes do
        primary :id, Int32
        column :parent_id, Int32, null: true
        column :name, String
      end
    end

    before_each do
      tree.nodes.create!
      [{1, nil, "root"}, {2, 1, "a"}, {3, 2, "b"}, {4, 1, "c"}, {5, nil, "other"}].each do |id, parent, name|
        tree.insert.into(:nodes).values(id: id, parent_id: parent, name: name).commit
      end
    end
    after_each { tree.nodes.drop! }

    it "walks descendants of a node" do
      anchor = tree.query.from(:nodes).select(:id, :parent_id, :name).where(id: 1)
      query = tree.query.with_recursive(:descendants, anchor) do |step|
        step.from(:descendants)
          .join(:nodes) { |j| j.nodes.parent_id.eq(j.descendants.id) }
          .select(nodes: [:id, :parent_id, :name])
      end.from(:descendants).select(:name).order(id: :asc)

      query.to_sql[0].should start_with("WITH RECURSIVE descendants AS (SELECT nodes.id, nodes.parent_id, nodes.name FROM nodes WHERE nodes.id = ? UNION ALL SELECT ")
      query.all(as: String).should eq(%w[root a b c])
    end
  end
end
