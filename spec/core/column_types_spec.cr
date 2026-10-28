require "../spec_helper"

ColumnTypesPostgresDB = CQL::Schema.define(
  :column_types_postgres,
  adapter: postgres_available? ? CQL::Adapter::Postgres : CQL::Adapter::SQLite,
  uri: postgres_available? ? postgres_database_url : spec_sqlite_uri("column_types_pg_fallback.db")
) do
  table :column_types_rows do
    primary :id, Int64, auto_increment: true
    timestamp :happened_at
    date :happened_on, null: true
  end

  table :column_type_defaults do
    primary :id, Int64, auto_increment: true
    timestamp :published_at, default: "CURRENT_TIMESTAMP"
    text :label, default: "CURRENT_TIMESTAMP"
  end
end

ColumnTypesSqliteDB = CQL::Schema.define(:column_types_sqlite, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("column_types.db")) do
  table :column_types_rows do
    primary :id, Int64, auto_increment: true
    date :happened_on
  end

  table :column_type_defaults do
    primary :id, Int64, auto_increment: true
    timestamp :published_at, default: "CURRENT_TIMESTAMP"
    text :label, default: "CURRENT_TIMESTAMP"
  end
end

# A MySQL-dialect schema over a SQLite connection it never uses: only its generated SQL is checked.
ColumnTypesMySqlDB = CQL::Schema.define(:column_types_mysql, "mysql://localhost/cql_spec", CQL::Adapter::MySql,
  source: CQL::DatabaseSource.new(DB.open("sqlite3://%3Amemory%3A?initial_pool_size=0"))) do
  table :column_type_defaults do
    primary :id, Int64, auto_increment: true
    timestamp :published_at, default: "current_timestamp"
    timestamp :edited_at, default: "2024-01-01 00:00:00"
    date :published_on, default: "CURRENT_TIMESTAMP"
  end
end

describe "Column types" do
  it "declares Time columns with a type that keeps the time of day" do
    CQL::Adapter::SQLite.sql_type(Time).should eq("TIMESTAMP")
    CQL::Adapter::Postgres.sql_type(Time).should eq("TIMESTAMP")
    CQL::Adapter::CockroachDB.sql_type(Time).should eq("TIMESTAMP")
    CQL::Adapter::MySql.sql_type(Time).should eq("DATETIME(3)")
  end

  it "declares date columns DATE" do
    table = ColumnTypesSqliteDB.column_types_rows

    table.create_sql.should contain("happened_on DATE NOT NULL")
    table.columns[:happened_on].copy_to(table).type.should eq("DATE")
  end

  it "gives MySQL timestamps the precision of their NOW(3) default" do
    mysql = CQL::Adapter::MySql

    mysql.dialect.define_column("created_at", mysql.sql_type(Time), mysql.dialect.current_timestamp, false, false, true)
      .should contain("created_at DATETIME(3) DEFAULT NOW(3)")
  end

  it "keeps the time of day in a timestamp column and only the date in a date column on PostgreSQL" do
    require_postgres!
    table = ColumnTypesPostgresDB.column_types_rows
    table.drop!
    table.create!
    happened_at = Time.utc(2026, 10, 25, 17, 30, 15)

    id = CQL::Insert.new(ColumnTypesPostgresDB).into(:column_types_rows).values(happened_at: happened_at, happened_on: happened_at).last_insert_id
    row = ColumnTypesPostgresDB.query.from(:column_types_rows).select(:happened_at, :happened_on).where(id: id).get({Time, Time})
    row.should eq({happened_at, happened_at.at_beginning_of_day})
  ensure
    ColumnTypesPostgresDB.column_types_rows.drop! if postgres_available?
  end

  describe "a CURRENT_TIMESTAMP default" do
    create_sql = ->(adapter : CQL::Adapter) { Expression::CreateTable.new(ColumnTypesSqliteDB.column_type_defaults).accept(Expression::Generator.new(adapter)) }

    it "is each dialect's current-time expression on any Time column, not a quoted string" do
      ColumnTypesSqliteDB.column_type_defaults.create_sql.should match(/published_at \S+ DEFAULT \(datetime\('now'\)\)/)
      create_sql.call(CQL::Adapter::Postgres).should match(/published_at \S+ DEFAULT CURRENT_TIMESTAMP\b/)
      create_sql.call(CQL::Adapter::MySql).should match(/published_at \S+ DEFAULT NOW\(3\)/)
    end

    it "is NOW(3) on a MySQL DATETIME(3) column in any case; another string, or a date column, stays quoted" do
      sql = ColumnTypesMySqlDB.column_type_defaults.create_sql
      sql.should contain("published_at DATETIME(3) DEFAULT NOW(3) NOT NULL")
      sql.should contain("edited_at DATETIME(3) DEFAULT '2024-01-01 00:00:00' NOT NULL")
      sql.should contain("published_on DATE DEFAULT 'CURRENT_TIMESTAMP' NOT NULL")
    end

    it "stays a quoted string literal on a String column" do
      [CQL::Adapter::SQLite, CQL::Adapter::Postgres, CQL::Adapter::MySql].each do |adapter|
        create_sql.call(adapter).should match(/label \S+ DEFAULT 'CURRENT_TIMESTAMP'/)
      end
    end

    it "stores the insert time in a SQLite row that omits the column" do
      table = ColumnTypesSqliteDB.column_type_defaults
      table.drop!
      table.create!

      id = CQL::Insert.new(ColumnTypesSqliteDB).into(:column_type_defaults).values(label: "row").last_insert_id
      ColumnTypesSqliteDB.query.from(:column_type_defaults).select(:published_at).where(id: id).get!(String)
        .should match(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/)
    ensure
      ColumnTypesSqliteDB.column_type_defaults.drop!
    end

    it "creates the table and stores the insert time on PostgreSQL" do
      require_postgres!
      table = ColumnTypesPostgresDB.column_type_defaults
      table.drop!
      table.create!

      id = CQL::Insert.new(ColumnTypesPostgresDB).into(:column_type_defaults).values(label: "row").last_insert_id
      published_at = ColumnTypesPostgresDB.query.from(:column_type_defaults).select(:published_at).where(id: id).get!(Time)
      (published_at - Time.utc).abs.should be < 1.day
    ensure
      ColumnTypesPostgresDB.column_type_defaults.drop! if postgres_available?
    end
  end
end
