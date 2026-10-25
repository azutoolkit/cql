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
end

ColumnTypesSqliteDB = CQL::Schema.define(:column_types_sqlite, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("column_types.db")) do
  table :column_types_rows do
    primary :id, Int64, auto_increment: true
    date :happened_on
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
end
