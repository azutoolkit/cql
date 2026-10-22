require "../spec_helper"

describe Expression::Raw do
  pg = -> { Expression::Generator.new(CQL::Adapter::Postgres) }
  base = -> { Northwind.query.from(:customers).select(:name) }

  describe "positional ? binds" do
    it "binds each value as a parameter" do
      sql, params = base.call.where("lower(customers.name) = ? AND customers.balance > ?", "ada", 10).to_sql

      sql.should eq("SELECT customers.name FROM customers WHERE lower(customers.name) = ? AND customers.balance > ?")
      params.should eq(["ada", 10] of DB::Any)
    end

    it "uses numbered placeholders on PostgreSQL" do
      sql, params = base.call.where(city: "Tulum").where("balance > ? AND balance < ?", 1, 9).to_sql(pg.call)

      sql.should end_with("WHERE (customers.city = $1) AND (balance > $2 AND balance < $3)")
      params.should eq(["Tulum", 1, 9] of DB::Any)
    end

    it "expands an array into a comma-separated list" do
      sql, params = base.call.where("customers.id IN (?)", [1, 2, 3]).to_sql

      sql.should end_with("WHERE customers.id IN (?, ?, ?)")
      params.should eq([1, 2, 3] of DB::Any)
    end

    it "binds nil as NULL" do
      _, params = base.call.where("customers.city IS NOT DISTINCT FROM ?", nil).to_sql
      params.should eq([nil] of DB::Any)
    end

    it "treats ?? as a literal question mark (PostgreSQL's jsonb operator)" do
      sql, params = base.call.where("data ?? 'key' AND id = ?", 1).to_sql(pg.call)

      sql.should end_with("data ? 'key' AND id = $1")
      params.should eq([1] of DB::Any)
    end
  end

  describe "named :name binds" do
    it "binds named values and repeats them where they repeat" do
      sql, params = base.call.where("balance BETWEEN :min AND :max OR credit > :min", min: 5, max: 9).to_sql

      sql.should end_with("WHERE balance BETWEEN ? AND ? OR credit > ?")
      params.should eq([5, 9, 5] of DB::Any)
    end

    it "numbers named binds per occurrence on PostgreSQL" do
      sql, params = base.call.where("a = :v OR b = :v", v: "x").to_sql(pg.call)

      sql.should end_with("a = $1 OR b = $2")
      params.should eq(["x", "x"] of DB::Any)
    end

    it "expands arrays for named binds" do
      sql, params = base.call.where("id IN (:ids)", ids: [4, 5]).to_sql

      sql.should end_with("id IN (?, ?)")
      params.should eq([4, 5] of DB::Any)
    end
  end

  describe "what is not a placeholder" do
    it "leaves placeholders inside quoted strings and identifiers alone" do
      fragment = %(note = 'what? :not_a_bind' AND "odd?col" = ? AND t = 'it''s ?')
      sql, params = base.call.where(fragment, 1).to_sql

      sql.should end_with(fragment)
      params.should eq([1] of DB::Any)
    end

    it "leaves :: casts alone" do
      sql, params = base.call.where("customers.id::text = :id", id: "7").to_sql

      sql.should end_with("customers.id::text = ?")
      params.should eq(["7"] of DB::Any)
    end

    it "keeps hostile values out of the SQL text" do
      sql, params = base.call.where("customers.name = ?", "x'; DROP TABLE customers; --").to_sql

      sql.should_not contain("DROP")
      params.should eq(["x'; DROP TABLE customers; --"] of DB::Any)
    end
  end

  describe "validation" do
    it "rejects too few or too many positional values" do
      expect_raises(ArgumentError, /expects 2 value\(s\), got 1/) { base.call.where("a = ? AND b = ?", 1) }
      expect_raises(ArgumentError, /expects 1 value\(s\), got 2/) { base.call.where("a = ?", 1, 2) }
    end

    it "rejects missing and unused named values" do
      expect_raises(ArgumentError, /Missing value for :max/) { base.call.where("a < :max", min: 1) }
      expect_raises(ArgumentError, /Unused named value\(s\): :extra/) { base.call.where("a < :max", max: 1, extra: 2) }
    end

    it "rejects values given in the wrong style instead of dropping them" do
      expect_raises(ArgumentError, /no :name placeholders/) { base.call.where("a = 1", tenant: 5) }
      expect_raises(ArgumentError, /no :name placeholders/) { base.call.where("a = ?", 1, foo: 2) }
      expect_raises(ArgumentError, /uses :name placeholders/) { base.call.where("a = :x", 5, x: 1) }
      expect_raises(ArgumentError, /expects 0 value\(s\), got 1/) { base.call.where("a = 1", 5) }
    end

    it "rejects mixing positional and named placeholders" do
      expect_raises(ArgumentError, /mix/) { base.call.where("a = ? AND b = :b", 1, b: 2) }
    end

    it "rejects empty arrays instead of generating invalid SQL" do
      expect_raises(ArgumentError, /empty array/) { base.call.where("id IN (?)", [] of Int32) }
    end
  end

  describe "comments and edge cases" do
    it "ignores placeholders inside -- and /* */ comments" do
      sql, params = base.call.where("a = ? -- really? :x\n AND b = ? /* :y ? */", 1, 2).to_sql

      params.should eq([1, 2] of DB::Any)
      sql.should contain("-- really? :x")
      sql.should contain("/* :y ? */")
    end

    it "does not let an apostrophe in a comment swallow later placeholders" do
      _, params = base.call.where("a = ? -- don't\n AND b = ?", 1, 2).to_sql
      params.should eq([1, 2] of DB::Any)
    end

    it "copies an unterminated quote verbatim" do
      sql, params = base.call.where("a = ? AND b = 'oops ?", 1).to_sql

      params.should eq([1] of DB::Any)
      sql.should end_with("b = 'oops ?")
    end

    it "handles very long quoted literals without hitting regex limits" do
      long = "x" * 200_000
      sql, params = base.call.where("a = ? AND note = '#{long}'", 1).to_sql

      params.should eq([1] of DB::Any)
      sql.should end_with("note = '#{long}'")
    end

    it "rejects a NUL byte in the fragment" do
      expect_raises(ArgumentError, /NUL/) { base.call.where("a = ?\0", 1) }
    end
  end

  describe "keyword compatibility" do
    it "still filters on a column named sql" do
      table = CQL::Schema.define(:raw_kw, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("raw_kw.db")) do
        table :snippets do
          primary :id, Int32
          column :sql, String
          column :city, String
        end
      end

      sql, params = table.query.from(:snippets).where(sql: "abc", city: "x").to_sql
      sql.should contain("snippets.sql = ?")
      params.should eq(["abc", "x"] of DB::Any)
    end
  end

  describe "composition" do
    it "ANDs with other where clauses" do
      sql, params = base.call.where(city: "Tulum").where("balance > ?", 5).to_sql

      sql.should end_with("WHERE (customers.city = ?) AND (balance > ?)")
      params.should eq(["Tulum", 5] of DB::Any)
    end

    it "is usable inside the block DSL via raw and combines with & and |" do
      sql, params = base.call.where { raw("lower(customers.name) = ?", "ada") | (customers.id == 1) }.to_sql

      sql.should end_with("WHERE (lower(customers.name) = ?) OR (customers.id = ?)")
      params.should eq(["ada", 1] of DB::Any)
    end

    it "is exposed as CQL.raw" do
      CQL.raw("a = ?", 1).should be_a(Expression::ConditionBuilder)
    end

    it "works in Update and Delete" do
      _, update_params = Northwind.update.table(:customers).set(city: "X").where("balance > :b", b: 3).to_sql
      _, delete_params = Northwind.delete.from(:customers).where("balance > ?", 3).to_sql

      update_params.should eq(["X", 3] of DB::Any)
      delete_params.should eq([3] of DB::Any)
    end

    it "keeps outer parameters when nested in a subquery" do
      sub = Northwind.query.from(:orders).select(:customer_id).where("orders.total > ?", 1000)
      _, params = base.call.where(city: "Tulum").where { customers.id.in(sub) }.to_sql

      params.should eq(["Tulum", 1000] of DB::Any)
    end
  end

  describe "ActiveRecord entry points" do
    before_each { UserDB.users.create! }
    after_each { UserDB.users.drop! }

    it "supports fragments on models and builders" do
      sql, params = TestUser.where("age > ?", 18).query.to_sql
      sql.should end_with("WHERE age > ?")
      params.should eq([18] of DB::Any)

      TestUser.query.where("age > :a", a: 18).where("name = ?", "x").query.to_sql[1].should eq([18, "x"] of DB::Any)
    end

    it "filters rows when executed" do
      %w[ada grace].each_with_index do |name, i|
        UserDB.insert.into(:users).values(name: name, email: "#{name}@example.com", age: 20 + i * 20, password: "pw").commit
      end

      TestUser.where("age > ?", 30).all.map(&.name).should eq(["grace"])
      TestUser.where("name IN (?)", ["ada", "grace"]).all.size.should eq(2)
    end
  end
end
