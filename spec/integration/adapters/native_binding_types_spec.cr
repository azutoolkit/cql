require "../spec_helper"

module NativeBindingTypesSpec
  Mapping = CQL::Schema.define(:native_binding, adapter: CQL::Adapter::Postgres) do
    table :native_binding_keys do
      primary :key, UUID
      text :body, sql_type: :text
    end
    table :native_binding_records do
      primary :id, UUID
      text :body, sql_type: :text
      timestamp :observed_at, sql_type: :timestamptz
    end
  end

  struct KeyRecord
    include CQL::Model(UUID)
    db_context schema: Mapping, table: :native_binding_keys, primary_key: :key
    property body : String = ""
  end

  class Record
    include CQL::Model(UUID)
    db_context schema: Mapping, table: :native_binding_records
    property body : String = ""
    property observed_at : Time = Time.utc
  end
end

describe "native PostgreSQL bindings and types" do
  it "round trips UUIDs and instants, dumps the borrowed schema and never aborts readiness on an absent ledger" do
    require_postgres!
    DB.open(postgres_database_url) do |db|
      db.transaction do |tx|
        connection = tx.connection
        connection.exec("CREATE SCHEMA native_binding_types")
        connection.exec("SET LOCAL search_path TO native_binding_types")
        binding = CQL::Binding.new(tx)
        schema = NativeBindingTypesSpec::Mapping.bind(binding)
        CQL::Migrator.ready?(schema, CQL::MigratorConfig.new(migration_namespace: "NativeBindingTypesSpec")).should be_false
        connection.scalar("SELECT 1").should eq(1)
        schema.build
        types = connection.query_all("SELECT data_type FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='native_binding_records' ORDER BY ordinal_position", as: String)
        types.should eq(["uuid", "text", "timestamp with time zone"])
        records = NativeBindingTypesSpec::Record.on(binding)
        observed = Time.utc(2026, 10, 31, 12, 30, 0)
        record = records.create!(body: "native", observed_at: observed)
        records.find!(record.id!).body.should eq("native")
        records.select(:id).first!.id.should eq(record.id)
        connection.exec("SET LOCAL TIME ZONE 'America/New_York'")
        records.find!(record.id!).observed_at.to_utc.should eq(observed)
        record.body = "updated"
        record.save!
        dumped = CQL::SchemaDump.open(schema, &.generate_schema_content(:NativeDump, :native_dump))
        dumped.should contain("primary :id, UUID, auto_increment: false")
        dumped.should contain("sql_type: :text")
        dumped.should contain("sql_type: :timestamptz")
        schema.alter :native_binding_records do
          add_column :extra, String, sql_type: :text
          change_column :observed_at, Time, sql_type: :timestamptz
          rename_column :extra, :renamed
        end
        records.insert_all([{body: "bulk one", observed_at: observed}, {body: "bulk two", observed_at: observed}]).should eq(2)
        records.ids(as: UUID).size.should eq(3)
        records.query.delete_all.should eq(3)
        key = UUID.random
        keys = NativeBindingTypesSpec::KeyRecord.on(binding)
        returned = keys.insert.values(key: key.to_s, body: "natural").back(:key, :body).get!(NativeBindingTypesSpec::KeyRecord)
        returned.id.should eq(key)
        keys.select(:id).first!.id.should eq(key)
        keys.find!(key).body.should eq("natural")
        keys.delete_ids([key]).should eq(1)
        db.query_one("SELECT to_regclass('native_binding_types.native_binding_records')::text", as: String?).should be_nil
        tx.rollback
      end
    end
  end
end
