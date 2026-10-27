require "../../spec_helper"

describe "CockroachDB adapter" do
  cockroach = CQL::Adapter::CockroachDB

  it "is a PostgreSQL-compatible adapter with its own dialect" do
    cockroach.dialect.should be_a(Expression::CockroachDialect)
    cockroach.dialect.should be_a(Expression::PostgresDialect)
    cockroach.postgres_compatible?.should be_true
    CQL::Adapter::Postgres.postgres_compatible?.should be_true
    CQL::Adapter::SQLite.postgres_compatible?.should be_false
  end

  it "uses PostgreSQL placeholders and column types" do
    cockroach.dialect.placeholder_format(3).should eq("$3")
    cockroach.sql_type(Int64).should eq("BIGINT")
    cockroach.sql_type(JSON::Any).should eq("JSONB")
    cockroach.sql_type(Slice(UInt8)).should eq("BYTEA")
  end

  it "returns inserted rows, as PostgreSQL does and SQLite and MySQL do not" do
    cockroach.dialect.supports_returning?.should be_true
    CQL::Adapter::Postgres.dialect.supports_returning?.should be_true
    CQL::Adapter::SQLite.dialect.supports_returning?.should be_false
    CQL::Adapter::MySql.dialect.supports_returning?.should be_false
  end

  it "rolls back DDL with its transaction, as PostgreSQL and SQLite do and MySQL and CockroachDB do not" do
    cockroach.dialect.supports_transactional_ddl?.should be_false
    CQL::Adapter::Postgres.dialect.supports_transactional_ddl?.should be_true
    CQL::Adapter::SQLite.dialect.supports_transactional_ddl?.should be_true
    CQL::Adapter::MySql.dialect.supports_transactional_ddl?.should be_false
  end

  it "serialises migrators with a transaction-scoped advisory lock on PostgreSQL only" do
    CQL::Adapter::Postgres.dialect.migration_lock_sql.to_s.should contain("pg_advisory_xact_lock")
    cockroach.dialect.migration_lock_sql.should be_nil
    CQL::Adapter::SQLite.dialect.migration_lock_sql.should be_nil
    CQL::Adapter::MySql.dialect.migration_lock_sql.should be_nil
  end

  it "lets PostgreSQL migrators wait for the lock at READ COMMITTED only, as their snapshot follows the wait" do
    postgres = CQL::Adapter::Postgres.dialect
    postgres.transaction_isolation_sql.should eq("SHOW transaction_isolation")
    {"read committed", "read uncommitted"}.each { |level| postgres.migration_lock_isolation_safe?(level).should be_true }
    {"repeatable read", "serializable"}.each { |level| postgres.migration_lock_isolation_safe?(level).should be_false }
    {CQL::Adapter::SQLite, CQL::Adapter::MySql}.each do |adapter|
      adapter.dialect.transaction_isolation_sql.should be_nil
      adapter.dialect.migration_lock_isolation_safe?("serializable").should be_true
    end
  end

  it "allows 32767 bound parameters, the most every driver accepts" do
    cockroach.dialect.max_bind_params.should eq(32767)
  end

  it "generates PostgreSQL-style SQL for queries, CTEs, windows and upserts" do
    generator = -> { Expression::Generator.new(cockroach) }

    sql, params = Northwind.query.from(:customers).select(:name).where(city: "Tulum").limit(3).to_sql(generator.call)
    sql.should eq("SELECT customers.name FROM customers WHERE customers.city = $1 LIMIT $2")
    params.should eq(["Tulum", 3] of DB::Any)

    Northwind.query.from(:orders).window(:row_number, as: :rn, order_by: :id).to_sql(generator.call)[0].should contain("ROW_NUMBER() OVER (ORDER BY orders.id ASC) AS rn")
    Northwind.insert.into(:users).values(name: "a", email: "b").on_conflict(:email).do_update(:name).to_sql(generator.call)[0]
      .should end_with("ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name")
  end

  it "renders for CockroachDB without a connection" do
    Northwind.query.from(:customers).select(:name).limit(1).to_sql(for: cockroach)[0].should end_with("LIMIT $1")
  end

  it "has no pg_dump-style structure dump" do
    expect_raises(CQL::DialectError, /CockroachDB does not support/) do
      cockroach.dialect.structure_dump(URI.parse("cockroachdb://root@localhost:26257/defaultdb"))
    end
  end

  describe "configuration and URIs" do
    it "is detected from a cockroachdb:// URL" do
      config = CQL::Configure::Config.new
      config.db = "cockroachdb://root@localhost:26257/defaultdb"

      config.adapter.should eq(cockroach)
      config.db_config.should be_a(CQL::Configure::PostgreSQLConfig)
    end

    it "requires a host and opens through the PostgreSQL driver" do
      expect_raises(CQL::Schema::InvalidURIError, "Missing host in CockroachDB URI") do
        CQL::Schema.define(:crdb, adapter: cockroach, uri: "cockroachdb:///defaultdb") { }
      end

      # No server here: the error must come from connecting, not from an unknown driver or URI.
      begin
        CQL::Schema.define(:crdb, adapter: cockroach, uri: "cockroachdb://root@127.0.0.1:1/defaultdb") { }
      rescue ex
        ex.should_not be_a(CQL::Schema::InvalidURIError)
        ex.message.to_s.should_not contain("no driver was registered")
      end
    end
  end

  describe "integer widths" do
    it "maps Int32 to INT4 because INTEGER is 64-bit on CockroachDB" do
      cockroach.sql_type(Int32).should eq("INT4")
      cockroach.sql_type(Int64).should eq("BIGINT")
      cockroach.sql_type(UInt32).should eq("BIGINT")
      CQL::Adapter::Postgres.sql_type(Int32).should eq("INTEGER")
    end
  end

  describe "SSL and URL building" do
    it "applies SSL settings for CockroachDB" do
      ssl = CQL::Configure::SSLConfig.new
      ssl.mode = "verify-full"
      ssl.ca_path = "/certs/ca.crt"
      params = HTTP::Params.new
      ssl.apply_to_params(params, cockroach)

      params["sslmode"].should eq("verify-full")
      params["sslrootcert"].should eq("/certs/ca.crt")
      params["sslcert"]?.should be_nil
    end

    it "uses the CockroachDB driver scheme when SchemaDump connects" do
      expect_raises(CQL::SchemaDump::Error) do
        CQL::SchemaDump.new(cockroach, "cockroachdb://root@127.0.0.1:1/x")
      end.message.to_s.should_not contain("no driver was registered")
    end

    it "keeps query parameters already present in the URL, which win over configured ones" do
      builder = CQL::Configure::DatabaseURLBuilder.new("cockroachdb://root@h:26257/db?sslmode=verify-full&options=--cluster%3Dx")
        .with_ssl(CQL::Configure::SSLConfig.new)
      url = URI.parse(builder.build)
      params = HTTP::Params.parse(url.query.to_s)

      url.scheme.should eq("cockroachdb")
      params["sslmode"].should eq("verify-full")
      params["options"].should eq("--cluster=x")
    end

    it "builds the full URL of a configuration" do
      config = CQL::Configure::Config.new
      config.db = "cockroachdb://root@localhost:26257/defaultdb"

      config.full_db_url.should start_with("cockroachdb://root@localhost:26257/defaultdb?")
    end
  end
end
