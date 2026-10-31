require "../spec_helper"

describe "native SQL type declarations" do
  it "keeps defaults compatible and makes native types explicit" do
    schema = CQL::Schema.define(:native_types, adapter: CQL::Adapter::Postgres) do
      table :native_types do
        primary :id, UUID
        text :legacy
        text :body, sql_type: :text
        timestamp :legacy_time
        timestamp :observed_at, sql_type: :timestamptz
      end
    end
    sql = schema.native_types.create_sql
    sql.should contain("id UUID PRIMARY KEY")
    sql.should contain("legacy VARCHAR")
    sql.should contain("body TEXT")
    sql.should contain("legacy_time TIMESTAMP")
    sql.should contain("observed_at TIMESTAMPTZ")
    expect_raises(ArgumentError, "auto increment") { schema.native_types.primary(:bad, UUID, auto_increment: true) }
  end

  it "rejects incompatible types and unsupported time-zone storage" do
    schema = CQL::Schema.define(:native_bad, adapter: CQL::Adapter::SQLite) do
      table :native_bad do
        column :bad, Int64, sql_type: :text
      end
    end
    expect_raises(ArgumentError, "requires String") { schema.native_bad.create_sql }
    schema.table :native_bad do
      timestamp :bad, sql_type: :timestamptz
    end
    expect_raises(CQL::Error, "requires PostgreSQL") { schema.native_bad.create_sql }
  end
end
