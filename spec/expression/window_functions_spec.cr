require "../spec_helper"

STAFF = CQL::Schema.define(:window_staff, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("window_staff.db")) do
  table :staff do
    primary :id, Int32
    column :dept, String
    column :name, String
    column :salary, Int32
  end
end

describe "Window functions" do
  pg = -> { Expression::Generator.new(CQL::Adapter::Postgres) }
  staff = -> { STAFF.query.from(:staff).select(:name) }

  describe "SQL generation" do
    it "renders ranking functions with PARTITION BY and ORDER BY" do
      sql, params = staff.call.window(:row_number, as: :position, partition_by: :dept, order_by: {salary: :desc}).to_sql

      sql.should eq("SELECT staff.name, ROW_NUMBER() OVER (PARTITION BY staff.dept ORDER BY staff.salary DESC) AS position FROM staff")
      params.should be_empty
    end

    it "supports several partition and order columns" do
      sql, _ = staff.call.window(:rank, as: :r, partition_by: [:dept, :name], order_by: [:salary, :id]).to_sql
      sql.should contain("RANK() OVER (PARTITION BY staff.dept, staff.name ORDER BY staff.salary ASC, staff.id ASC) AS r")
    end

    it "renders aggregates over a window" do
      sql, _ = staff.call.window(:sum, :salary, as: :dept_total, partition_by: :dept).to_sql
      sql.should contain("SUM(staff.salary) OVER (PARTITION BY staff.dept) AS dept_total")
    end

    it "renders an empty OVER ()" do
      staff.call.window(:count, as: :n).to_sql[0].should contain("COUNT(*) OVER () AS n")
    end

    it "renders value functions with offsets" do
      sql, _ = staff.call.window(:lag, :salary, offset: 2, as: :before, order_by: :id).to_sql
      sql.should contain("LAG(staff.salary, 2) OVER (ORDER BY staff.id ASC) AS before")
      staff.call.window(:first_value, :name, as: :top, order_by: {salary: :desc}).to_sql[0].should contain("FIRST_VALUE(staff.name) OVER (ORDER BY staff.salary DESC) AS top")
    end

    it "renders NTILE with its bucket count" do
      staff.call.window(:ntile, buckets: 4, as: :quartile, order_by: :salary).to_sql[0].should contain("NTILE(4) OVER (ORDER BY staff.salary ASC) AS quartile")
    end

    it "renders ROWS and RANGE frames" do
      moving = staff.call.window(:avg, :salary, as: :moving, order_by: :id, rows: {-2, 0}).to_sql[0]
      moving.should contain("AVG(staff.salary) OVER (ORDER BY staff.id ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving")

      running = staff.call.window(:sum, :salary, as: :running, order_by: :id, rows: {:unbounded_preceding, 0}).to_sql[0]
      running.should contain("ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW")

      ahead = staff.call.window(:sum, :salary, as: :ahead, order_by: :id, range: {0, :unbounded_following}).to_sql[0]
      ahead.should contain("RANGE BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING")
      staff.call.window(:sum, :salary, as: :next_two, order_by: :id, rows: {1, 2}).to_sql[0].should contain("ROWS BETWEEN 1 FOLLOWING AND 2 FOLLOWING")
    end

    it "quotes the alias when identifier quoting is on" do
      sql, _ = staff.call.window(:row_number, as: :position, order_by: :id).to_sql(Expression::Generator.new(CQL::Adapter::Postgres, quote_identifiers: true))
      sql.should contain("OVER (ORDER BY \"staff\".\"id\" ASC) AS \"position\"")
    end

    it "keeps parameter order with a WHERE clause" do
      sql, params = staff.call.window(:row_number, as: :rn, order_by: :id).where(dept: "eng").to_sql(pg.call)

      params.should eq(["eng"] of DB::Any)
      sql.should end_with("WHERE staff.dept = $1")
    end

    it "coexists with aggregates, in the order they were added" do
      sql, _ = STAFF.query.from(:staff).count(as: :n).window(:row_number, as: :rn, order_by: :id).to_sql
      sql.should start_with("SELECT COUNT(*) AS n, ROW_NUMBER() OVER (ORDER BY staff.id ASC) AS rn FROM staff")
    end
  end

  describe "validation" do
    it "requires a column for functions that take one" do
      expect_raises(ArgumentError, /sum needs a column/) { staff.call.window(:sum, as: :x) }
      expect_raises(ArgumentError, /row_number takes no column/) { staff.call.window(:row_number, :salary, as: :x) }
    end

    it "requires buckets for NTILE only" do
      expect_raises(ArgumentError, /ntile needs buckets/) { staff.call.window(:ntile, as: :x) }
      expect_raises(ArgumentError, /buckets must be positive/) { staff.call.window(:ntile, buckets: 0, as: :x) }
      expect_raises(ArgumentError, /buckets only applies to ntile/) { staff.call.window(:rank, buckets: 2, as: :x) }
    end

    it "rejects unknown functions, columns and bad aliases" do
      expect_raises(ArgumentError, /Unknown window function/) { staff.call.window(:median, :salary, as: :x) }
      expect_raises(ArgumentError, /not found/) { staff.call.window(:rank, as: :x, order_by: :nope) }
      expect_raises(ArgumentError, /Invalid alias/) { staff.call.window(:rank, as: :"x; DROP TABLE staff") }
    end

    it "rejects both ROWS and RANGE and malformed frames" do
      expect_raises(ArgumentError, /either rows or range/) { staff.call.window(:sum, :salary, as: :x, rows: {0, 0}, range: {0, 0}) }
      expect_raises(ArgumentError, /Invalid frame bound/) { staff.call.window(:sum, :salary, as: :x, rows: {:forever, 0}) }
    end
  end

  describe "executing against SQLite" do
    before_each do
      STAFF.staff.create!
      [{"eng", "ada", 300}, {"eng", "grace", 200}, {"eng", "linus", 100}, {"ops", "kim", 150}, {"ops", "lee", 50}].each do |dept, name, salary|
        STAFF.insert.into(:staff).values(dept: dept, name: name, salary: salary).commit
      end
    end
    after_each { STAFF.staff.drop! }

    it "ranks within each partition" do
      rows = STAFF.query.from(:staff).select(:name)
        .window(:row_number, as: :rn, partition_by: :dept, order_by: {salary: :desc})
        .order(name: :asc)
        .all(as: {String, Int64})

      rows.should eq([{"ada", 1}, {"grace", 2}, {"kim", 1}, {"lee", 2}, {"linus", 3}])
    end

    it "computes running totals and department totals" do
      rows = STAFF.query.from(:staff).select(:name)
        .window(:sum, :salary, as: :running, order_by: :id, rows: {:unbounded_preceding, 0})
        .window(:sum, :salary, as: :dept_total, partition_by: :dept)
        .order(id: :asc)
        .all(as: {String, Int64, Int64})

      rows.map(&.[1]).should eq([300, 500, 600, 750, 800])
      rows.map(&.[2]).should eq([600, 600, 600, 200, 200])
    end

    it "looks at the previous row" do
      rows = STAFF.query.from(:staff).select(:name)
        .window(:lag, :salary, as: :previous, order_by: :id)
        .order(id: :asc)
        .all(as: {String, Int64?})

      rows.map(&.[1]).should eq([nil, 300, 200, 100, 150])
    end

    it "selects the top two earners per department through a CTE" do
      ranked_staff = STAFF.query.from(:staff).select(:name, :dept)
        .window(:row_number, as: :rn, partition_by: :dept, order_by: {salary: :desc})

      top = STAFF.query.with(:ranked, ranked_staff).from(:ranked).select(:name)
        .where { ranked.rn <= 2 }
        .order(name: :asc)

      top.all(as: String).should eq(%w[ada grace kim lee])
    end
  end
end

describe "Window function validation (frames, offsets, argument shapes)" do
  staff = -> { STAFF.query.from(:staff).select(:name) }

  it "rejects frames that cannot be valid" do
    expect_raises(ArgumentError, /frame cannot start at :unbounded_following/) { staff.call.window(:sum, :salary, as: :x, order_by: :id, rows: {:unbounded_following, 0}) }
    expect_raises(ArgumentError, /frame cannot end at :unbounded_preceding/) { staff.call.window(:sum, :salary, as: :x, order_by: :id, rows: {0, :unbounded_preceding}) }
    expect_raises(ArgumentError, /frame start must not come after its end/) { staff.call.window(:sum, :salary, as: :x, order_by: :id, rows: {1, -1}) }
    expect_raises(ArgumentError, /frame offset is out of range/) { staff.call.window(:sum, :salary, as: :x, order_by: :id, rows: {Int32::MIN, 0}) }
  end

  it "requires ORDER BY for RANGE frames with offsets" do
    expect_raises(ArgumentError, /RANGE with an offset needs order_by/) { staff.call.window(:sum, :salary, as: :x, range: {-1, 1}) }
    staff.call.window(:sum, :salary, as: :x, range: {:unbounded_preceding, 0}).to_sql[0].should contain("RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW")
  end

  it "rejects negative lag and lead offsets" do
    expect_raises(ArgumentError, /offset must not be negative/) { staff.call.window(:lag, :salary, offset: -1, as: :x, order_by: :id) }
  end

  it "keeps working after clone and merge" do
    windowed = staff.call.window(:row_number, as: :rn, order_by: :id)
    windowed.clone.to_sql.should eq(windowed.to_sql)
    STAFF.query.from(:staff).merge(windowed).to_sql[0].should contain("ROW_NUMBER() OVER")
  end
end

describe "Built statements do not change when their source query does" do
  orders = -> { Northwind.query.from(:orders).select(:id) }

  it "snapshots joins used in a FROM subquery" do
    source = orders.call
    outer = Northwind.query.from(source, as: :d).select(:id)
    before = outer.to_sql
    source.join(:customers) { |j| j.customers.id.eq(j.orders.customer_id) }

    outer.to_sql.should eq(before)
  end

  it "snapshots CTEs used in a CTE body" do
    inner = orders.call
    outer = Northwind.query.with(:t, inner).from(:t).select(:id)
    before = outer.to_sql
    inner.with(:z, Northwind.query.from(:customers).select(:id))

    outer.to_sql.should eq(before)
  end

  it "does not let a later do_update change an already built upsert" do
    insert = Northwind.insert.into(:users).values(name: "a", email: "b").on_conflict(:email).do_update(:name, age: 1)
    node = insert.build
    insert.do_update(:name)

    node.conflict.not_nil!.assignments.size.should eq(1)
  end
end
