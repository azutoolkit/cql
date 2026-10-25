require "../../spec_helper"

# A table whose column names could collide with the quoting cache's methods.
QuotingNamesDB = CQL::Schema.define(:quoting_names, adapter: CQL::Adapter::SQLite, uri: "sqlite3::memory:", quote_identifiers: true) do
  table :accounts do
    primary :id, Int64
    text :identifier
    text :quoted_name
  end
end

describe "Opt-in identifier quoting" do
  pg = -> { Expression::Generator.new(CQL::Adapter::Postgres, quote_identifiers: true) }
  mysql = -> { Expression::Generator.new(CQL::Adapter::MySql, quote_identifiers: true) }

  describe "dialect#quote_identifier" do
    it "double-quotes for PostgreSQL and SQLite and doubles embedded quotes" do
      CQL::Adapter::Postgres.dialect.quote_identifier("user").should eq(%("user"))
      CQL::Adapter::SQLite.dialect.quote_identifier(%(a"b)).should eq(%("a""b"))
    end

    it "uses backticks for MySQL and doubles embedded backticks" do
      CQL::Adapter::MySql.dialect.quote_identifier("order").should eq("`order`")
      CQL::Adapter::MySql.dialect.quote_identifier("a`b").should eq("`a``b`")
    end
  end

  describe "generated SQL" do
    it "is unchanged by default" do
      sql, _ = Northwind.query.from(:customers).select(:name).where(city: "Tulum").to_sql
      sql.should eq("SELECT customers.name FROM customers WHERE customers.city = ?")
    end

    it "quotes tables and columns in SELECT for PostgreSQL" do
      sql, params = Northwind.query.from(:customers).select(:name).where(city: "Tulum").to_sql(pg.call)

      sql.should eq(%(SELECT "customers"."name" FROM "customers" WHERE "customers"."city" = $1))
      params.should eq(["Tulum"] of DB::Any)
    end

    it "uses backticks for MySQL" do
      sql, _ = Northwind.query.from(:customers).select(:name).to_sql(mysql.call)
      sql.should eq("SELECT `customers`.`name` FROM `customers`")
    end

    it "quotes table aliases and alias-qualified columns" do
      sql, _ = Northwind.query.from(customers: :c).select(:name).where { c.city == "Tulum" }.to_sql(pg.call)

      sql.should contain(%(FROM "customers" AS "c"))
      sql.should contain(%("c"."city" = $1))
    end

    it "quotes aggregate aliases but leaves * alone" do
      sql, _ = Northwind.query.from(:orders).count(as: :n).sum(:total, as: :revenue).to_sql(pg.call)
      sql.should eq(%(SELECT COUNT(*) AS "n", SUM("orders"."total") AS "revenue" FROM "orders"))
    end

    it "quotes INSERT table and column names" do
      sql, _ = Northwind.insert.into(:users).values(name: "Ada", email: "a@example.com").to_sql(pg.call)
      sql.should eq(%(INSERT INTO "users" ("name", "email") VALUES ($1, $2)))
    end

    it "quotes UPDATE and DELETE identifiers" do
      update_sql, _ = Northwind.update.table(:users).set(age: 31).where(name: "Ada").to_sql(pg.call)
      delete_sql, _ = Northwind.delete.from(:users).where(name: "Ada").to_sql(pg.call)

      update_sql.should eq(%(UPDATE "users" SET "age" = $1 WHERE "users"."name" = $2))
      delete_sql.should eq(%(DELETE FROM "users" WHERE "users"."name" = $1))
    end
  end

  describe "Schema flag" do
    it "defaults to off" do
      Northwind.quote_identifiers.should be_false
    end

    it "makes reserved-word tables and columns work end to end on SQLite" do
      schema = CQL::Schema.define(
        :quoting_db, adapter: CQL::Adapter::SQLite,
        uri: spec_sqlite_uri("quoting_spec.db"), quote_identifiers: true) do
        table :order do
          primary :id, Int32
          column :group, String
        end
      end

      schema.exec(%(DROP TABLE IF EXISTS "order"))
      schema.exec(%(CREATE TABLE "order" (id INTEGER PRIMARY KEY, "group" TEXT)))
      begin
        schema.insert.into(:order).values(group: "admins").commit
        sql, _ = schema.query.from(:order).select(:group).to_sql
        sql.should eq(%(SELECT "order"."group" FROM "order"))

        schema.query.from(:order).select(:group).all(as: String).should eq(["admins"])
      ensure
        schema.exec(%(DROP TABLE IF EXISTS "order"))
      end
    end
  end

  describe "quoted name cache" do
    postgres_dialect, mysql_dialect = CQL::Adapter::Postgres.dialect, CQL::Adapter::MySql.dialect

    it "quotes a table or column once per dialect and reuses the text" do
      table = Northwind.tables[:customers]
      column = table.columns[:name]

      table.__quoted_name(postgres_dialect, :customers).should eq(%("customers"))
      table.__quoted_name(postgres_dialect, :customers).should be(table.__quoted_name(postgres_dialect, :customers))
      column.__quoted_name(mysql_dialect, :name).should eq("`name`")
      column.__quoted_name(postgres_dialect, :name).should eq(%("name"))
      column.__quoted_name(mysql_dialect, :name).should eq("`name`")
    end

    it "renders the same table for two dialects with each one's quotes" do
      query = -> { Northwind.query.from(:customers).select(:name) }

      query.call.to_sql(pg.call)[0].should eq(%(SELECT "customers"."name" FROM "customers"))
      query.call.to_sql(mysql.call)[0].should eq("SELECT `customers`.`name` FROM `customers`")
      query.call.to_sql(pg.call)[0].should eq(%(SELECT "customers"."name" FROM "customers"))
    end

    it "quotes a renamed table or column by its new name" do
      table = CQL::Table.new(:before_rename, QuotingNamesDB)
      table.text(:old_name)
      quoted = -> { CQL::Query.new(QuotingNamesDB).from(table.table_name).select(table.columns.keys.first).to_sql(pg.call)[0] }
      QuotingNamesDB.tables[table.table_name] = table
      quoted.call.should eq(%(SELECT "before_rename"."old_name" FROM "before_rename"))

      table.columns[:old_name].name = :new_name
      QuotingNamesDB.tables.delete(:before_rename)
      table.table_name = :after_rename
      QuotingNamesDB.tables[:after_rename] = table

      CQL::Query.new(QuotingNamesDB).from(:after_rename).to_sql(pg.call)[0]
        .should eq(%(SELECT "after_rename"."new_name" FROM "after_rename"))
    ensure
      QuotingNamesDB.tables.delete(:before_rename)
      QuotingNamesDB.tables.delete(:after_rename)
    end

    it "quotes an alias equal to its table's name like the table" do
      Northwind.query.from(customers: :customers).select(:name).to_sql(pg.call)[0]
        .should eq(%(SELECT "customers"."name" FROM "customers"))
    end

    it "leaves columns named identifier and quoted_name reachable in the query DSL" do
      sql, params = QuotingNamesDB.query.from(:accounts).select(:quoted_name).where { accounts.identifier == "x" }.to_sql(pg.call)

      sql.should eq(%(SELECT "accounts"."quoted_name" FROM "accounts" WHERE "accounts"."identifier" = $1))
      params.should eq(["x"] of DB::Any)
    end
  end
end
