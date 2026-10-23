require "./spec_helper"

CreateBangSqliteDB = CQL::Schema.define(:create_bang_sqlite, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("create_bang.db")) do
  table :create_bang_rows do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :create_bang_small_rows do
    primary :id, Int32, auto_increment: true
    text :name
  end
end

CreateBangPostgresDB = CQL::Schema.define(
  :create_bang_postgres,
  adapter: postgres_available? ? CQL::Adapter::Postgres : CQL::Adapter::SQLite,
  uri: postgres_available? ? postgres_database_url : spec_sqlite_uri("create_bang_pg_fallback.db")
) do
  table :create_bang_rows do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :create_bang_small_rows do
    primary :id, Int32, auto_increment: true
    text :name
  end
end

{% for prefix in ["Sqlite", "Postgres"] %}
  class CreateBang{{prefix.id}}Row
    include CQL::ActiveRecord::Model(Int64)
    db_context schema: CreateBang{{prefix.id}}DB, table: :create_bang_rows
    property name : String = ""
  end

  class CreateBang{{prefix.id}}SmallRow
    include CQL::ActiveRecord::Model(Int32)
    db_context schema: CreateBang{{prefix.id}}DB, table: :create_bang_small_rows
    property name : String = ""
  end
{% end %}

{% for prefix in ["Sqlite", "Postgres"] %}
  describe "Model.create! with auto-increment keys ({{prefix.id}})" do
    before_each do
      {% if prefix == "Postgres" %}require_postgres!{% end %}
      CreateBang{{prefix.id}}DB.create_bang_rows.drop!
      CreateBang{{prefix.id}}DB.create_bang_rows.create!
      CreateBang{{prefix.id}}DB.create_bang_small_rows.drop!
      CreateBang{{prefix.id}}DB.create_bang_small_rows.create!
    end

    after_all do
      {% if prefix == "Postgres" %}next unless postgres_available?{% end %}
      CreateBang{{prefix.id}}DB.create_bang_rows.drop!
      CreateBang{{prefix.id}}DB.create_bang_small_rows.drop!
    end

    it "returns the stored row for keyword fields" do
      row = CreateBang{{prefix.id}}Row.create!(name: "ada")

      row.id.should eq(1)
      CreateBang{{prefix.id}}Row.count.should eq(1)
      row.name.should eq("ada")
    end

    it "returns the stored row for a hash of attributes" do
      row = CreateBang{{prefix.id}}Row.create!({:name => "ada".as(DB::Any)})

      row.name.should eq("ada")
      row.id.should eq(1)
    end

    it "supports Int32 keys" do
      CreateBang{{prefix.id}}SmallRow.create!(name: "a").id.should eq(1)
      CreateBang{{prefix.id}}SmallRow.create!({:name => "b".as(DB::Any)}).id.should eq(2)
    end

    it "keeps the instance path working" do
      record = CreateBang{{prefix.id}}Row.allocate
      record.name = "ada"

      created = CreateBang{{prefix.id}}Row.create!(record)

      created.name.should eq("ada")
      created.id.should eq(1)
    end

    it "supports Int32 keys on the instance path" do
      record = CreateBang{{prefix.id}}SmallRow.allocate
      record.name = "ada"

      CreateBang{{prefix.id}}SmallRow.create!(record).id.should eq(1)
    end
  end
{% end %}
