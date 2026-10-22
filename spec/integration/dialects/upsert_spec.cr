require "../../spec_helper"

ACCOUNTS = CQL::Schema.define(:upsert_accounts, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("upsert_accounts.db")) do
  table :accounts do
    primary :id, Int32
    column :email, String, unique: true
    column :name, String
    column :visits, Int32, default: 0
  end
end

describe "Upsert" do
  pg = -> { Expression::Generator.new(CQL::Adapter::Postgres) }
  mysql = -> { Expression::Generator.new(CQL::Adapter::MySql) }
  signup = -> { ACCOUNTS.insert.into(:accounts).values(email: "a@x.io", name: "Ada") }

  describe "SQL generation" do
    it "refreshes columns from the incoming row (PostgreSQL)" do
      sql, params = signup.call.on_conflict(:email).do_update(:name).to_sql(pg.call)

      sql.should eq("INSERT INTO accounts (email, name) VALUES ($1, $2) ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name")
      params.should eq(["a@x.io", "Ada"] of DB::Any)
    end

    it "does nothing on conflict" do
      signup.call.on_conflict(:email).do_nothing.to_sql(pg.call)[0].should end_with("ON CONFLICT (email) DO NOTHING")
      signup.call.on_conflict(:email).do_nothing.to_sql[0].should end_with("ON CONFLICT (email) DO NOTHING")
    end

    it "mixes refreshed columns with explicit values, binding them after the row values" do
      sql, params = signup.call.on_conflict(:email).do_update(:name, visits: 9).to_sql(pg.call)

      sql.should end_with("DO UPDATE SET name = EXCLUDED.name, visits = $3")
      params.should eq(["a@x.io", "Ada", 9] of DB::Any)
    end

    it "refreshes every non-target column when no columns are given" do
      signup.call.on_conflict(:email).do_update.to_sql(pg.call)[0].should end_with("ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name")
    end

    it "supports composite conflict targets" do
      signup.call.on_conflict(:email, :name).do_nothing.to_sql[0].should end_with("ON CONFLICT (email, name) DO NOTHING")
    end

    it "uses ON DUPLICATE KEY UPDATE on MySQL" do
      sql, params = signup.call.on_conflict(:email).do_update(:name, visits: 9).to_sql(mysql.call)

      sql.should end_with("ON DUPLICATE KEY UPDATE name = VALUES(name), visits = ?")
      params.should eq(["a@x.io", "Ada", 9] of DB::Any)
      signup.call.on_conflict(:email).do_nothing.to_sql(mysql.call)[0].should end_with("ON DUPLICATE KEY UPDATE email = email")
    end

    it "numbers every row of a bulk upsert and then the update values" do
      rows = [
        {:email => "a@x.io", :name => "Ada"} of Symbol => DB::Any,
        {:email => "g@x.io", :name => "Grace"} of Symbol => DB::Any,
      ]
      sql, params = ACCOUNTS.insert.into(:accounts).upsert(rows, conflict: [:email], update: [:name]).to_sql(pg.call)

      sql.should eq("INSERT INTO accounts (email, name) VALUES ($1, $2), ($3, $4) ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name")
      params.size.should eq(4)
    end

    it "keeps the conflict clause before RETURNING" do
      sql, _ = signup.call.on_conflict(:email).do_update(:name).back(:id).to_sql(pg.call)
      sql.should end_with("DO UPDATE SET name = EXCLUDED.name RETURNING accounts.id")
    end

    it "quotes identifiers when requested" do
      sql, _ = signup.call.on_conflict(:email).do_update(:name).to_sql(Expression::Generator.new(CQL::Adapter::Postgres, quote_identifiers: true))
      sql.should end_with("ON CONFLICT (\"email\") DO UPDATE SET \"name\" = EXCLUDED.\"name\"")

      mysql_sql, _ = signup.call.on_conflict(:email).do_update(:name).to_sql(Expression::Generator.new(CQL::Adapter::MySql, quote_identifiers: true))
      mysql_sql.should end_with("ON DUPLICATE KEY UPDATE `name` = VALUES(`name`)")
    end
  end

  describe "validation" do
    it "needs a conflict target before an action" do
      expect_raises(ArgumentError, /on_conflict/) { signup.call.do_nothing }
      expect_raises(ArgumentError, /on_conflict/) { signup.call.do_update(:name) }
    end

    it "rejects unknown columns" do
      expect_raises(Exception, /nope|not found/i) { signup.call.on_conflict(:nope) }
      expect_raises(Exception, /nope|not found/i) { signup.call.on_conflict(:email).do_update(:nope) }
    end

    it "rejects INSERT ... SELECT with a conflict clause" do
      source = ACCOUNTS.query.from(:accounts).select(:email, :name)
      insert = ACCOUNTS.insert.into(:accounts).query(source).on_conflict(:email).do_nothing

      expect_raises(ArgumentError, /INSERT \.\.\. SELECT/) { insert.to_sql }
    end

    it "requires an action before generating SQL" do
      expect_raises(ArgumentError, /do_nothing or do_update/) { signup.call.on_conflict(:email).to_sql }
    end
  end

  describe "executing against SQLite" do
    before_each { ACCOUNTS.accounts.create! }
    after_each { ACCOUNTS.accounts.drop! }

    it "updates the existing row on conflict" do
      signup.call.commit
      ACCOUNTS.insert.into(:accounts).values(email: "a@x.io", name: "Ada L.").on_conflict(:email).do_update(:name, visits: 5).commit

      ACCOUNTS.query.from(:accounts).select(:name, :visits).all(as: {String, Int32}).should eq([{"Ada L.", 5}])
    end

    it "keeps the existing row with DO NOTHING" do
      signup.call.commit
      ACCOUNTS.insert.into(:accounts).values(email: "a@x.io", name: "Other").on_conflict(:email).do_nothing.commit

      ACCOUNTS.query.from(:accounts).select(:name).all(as: String).should eq(["Ada"])
    end

    it "upserts many rows at once" do
      signup.call.commit
      rows = [
        {:email => "a@x.io", :name => "Ada Lovelace"} of Symbol => DB::Any,
        {:email => "g@x.io", :name => "Grace"} of Symbol => DB::Any,
      ]
      ACCOUNTS.insert.into(:accounts).upsert(rows, conflict: [:email], update: [:name]).commit

      ACCOUNTS.query.from(:accounts).select(:email, :name).order(email: :asc).all(as: {String, String})
        .should eq([{"a@x.io", "Ada Lovelace"}, {"g@x.io", "Grace"}])
    end
  end
end

describe "Upsert edge cases" do
  it "names the table and column for an unknown conflict column" do
    expect_raises(ArgumentError, /Column nope not found in accounts/) do
      ACCOUNTS.insert.into(:accounts).values(email: "a", name: "b").on_conflict(:nope)
    end
  end

  it "treats an empty update list in upsert as 'update nothing'" do
    rows = [{:email => "a@x.io", :name => "Ada"} of Symbol => DB::Any]
    ACCOUNTS.insert.into(:accounts).upsert(rows, conflict: [:email], update: [] of Symbol).to_sql[0].should end_with("ON CONFLICT (email) DO NOTHING")
  end
end
