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

  table :create_bang_defaulted_rows do
    primary :id, Int64, auto_increment: true
    text :name
    text :status, default: "draft"
    timestamp :deleted_at, null: true
  end

  table :create_bang_coded_rows do
    primary :id, Int64, auto_increment: true
    text :code, unique: true
    boolean :flag, default: false
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

  table :create_bang_defaulted_rows do
    primary :id, Int64, auto_increment: true
    text :name
    text :status, default: "draft"
    timestamp :deleted_at, null: true
  end

  table :create_bang_coded_rows do
    primary :id, Int64, auto_increment: true
    text :code, unique: true
    boolean :flag, default: false
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

  class CreateBang{{prefix.id}}DefaultedRow
    include CQL::ActiveRecord::Model(Int64)
    db_context schema: CreateBang{{prefix.id}}DB, table: :create_bang_defaulted_rows
    property name : String = ""
    property status : String = ""
  end

  class CreateBang{{prefix.id}}SoftRow
    include CQL::ActiveRecord::Model(Int64)
    include CQL::ActiveRecord::SoftDeletable
    db_context schema: CreateBang{{prefix.id}}DB, table: :create_bang_defaulted_rows
    property name : String = ""
    property status : String = ""
  end

  class CreateBang{{prefix.id}}SubRow < CreateBang{{prefix.id}}DefaultedRow
  end

  # A per-call scope: create! must read the row back through it, as before.
  class CreateBang{{prefix.id}}ScopedRow
    include CQL::ActiveRecord::Model(Int64)
    db_context schema: CreateBang{{prefix.id}}DB, table: :create_bang_defaulted_rows
    property name : String = ""
    property status : String = ""

    def self.query
      previous_def.where(status: "draft")
    end
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
      CreateBang{{prefix.id}}DB.create_bang_defaulted_rows.drop!
      CreateBang{{prefix.id}}DB.create_bang_defaulted_rows.create!
      CreateBang{{prefix.id}}DB.create_bang_coded_rows.drop!
      CreateBang{{prefix.id}}DB.create_bang_coded_rows.create!
    end

    after_all do
      {% if prefix == "Postgres" %}next unless postgres_available?{% end %}
      CreateBang{{prefix.id}}DB.create_bang_rows.drop!
      CreateBang{{prefix.id}}DB.create_bang_small_rows.drop!
      CreateBang{{prefix.id}}DB.create_bang_defaulted_rows.drop!
      CreateBang{{prefix.id}}DB.create_bang_coded_rows.drop!
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

    it "loads the columns the database filled in" do
      CreateBang{{prefix.id}}DefaultedRow.create!(name: "ada").status.should eq("draft")
      CreateBang{{prefix.id}}DefaultedRow.create!({:name => "bob".as(DB::Any)}).status.should eq("draft")
    end

    it "refuses to read back an insert without columns to return, before inserting" do
      insert = CQL::Insert.new(CreateBang{{prefix.id}}DB).into(:create_bang_coded_rows).values(code: "a")

      expect_raises(ArgumentError, /back/) { insert.get(Int64) }
      CreateBang{{prefix.id}}DB.query.from(:create_bang_coded_rows).count.get(Int64).should eq(0)
    end

    it "creates through a subclass of the model" do
      CreateBang{{prefix.id}}SubRow.create!(name: "ada").status.should eq("draft")
    end

    {% if prefix == "Postgres" %}
      it "reads the row back from the INSERT's RETURNING clause" do
        row = nil
        inserts = [] of String
        selects = count_queries do
          inserts = count_queries(:insert) { row = CreateBangPostgresDefaultedRow.create!(name: "ada") }
        end

        selects.should be_empty
        inserts.size.should eq(1)
        inserts.first.should contain(" RETURNING ")
        row.try(&.status).should eq("draft")
        row.try(&.id).should eq(1)
      end

      it "reads an insert's returned row, nil when a conflict skips it" do
        insert = -> { CQL::Insert.new(CreateBangPostgresDB).into(:create_bang_coded_rows).values(code: "a").back(:id, :code) }

        insert.call.get!({Int64, String}).should eq({1_i64, "a"})
        CQL::Insert.new(CreateBangPostgresDB).into(:create_bang_coded_rows).values(code: "b").back(:flag).get!(Bool).should be_false
        insert.call.on_conflict(:code).do_nothing.get({Int64, String}).should be_nil
        expect_raises(DB::NoResultsError) { insert.call.on_conflict(:code).do_nothing.get!({Int64, String}) }
      end

      it "reads the row back by id for a subclass of the model" do
        count_queries { CreateBangPostgresSubRow.create!(name: "ada") }.size.should eq(1)
      end

      it "returns a soft-deletable record from RETURNING, even one created deleted" do
        deleted_at = Time.utc.at_beginning_of_day
        selects = count_queries do
          CreateBangPostgresSoftRow.create!(name: "ada").status.should eq("draft")
          CreateBangPostgresSoftRow.create!(name: "bob", deleted_at: deleted_at).deleted_at.should eq(deleted_at)
        end

        selects.should be_empty
      end

      it "reads the row back through a model's own query scope" do
        selects = count_queries do
          CreateBangPostgresScopedRow.create!(name: "ada").status.should eq("draft")
        end

        selects.size.should eq(1)
        expect_raises(DB::NoResultsError) { CreateBangPostgresScopedRow.create!(name: "bob", status: "done") }
      end
    {% else %}
      it "refuses Insert#get where the dialect has no RETURNING, before inserting" do
        insert = CQL::Insert.new(CreateBangSqliteDB).into(:create_bang_coded_rows).values(code: "a").back(:id)

        expect_raises(CQL::DialectError, /RETURNING/) { insert.get(Int64) }
        CreateBangSqliteDB.query.from(:create_bang_coded_rows).count.get(Int64).should eq(0)
      end

      it "reads the row back with a SELECT where the database has no RETURNING" do
        count_queries { CreateBangSqliteDefaultedRow.create!(name: "ada") }.size.should eq(1)
      end
    {% end %}
  end
{% end %}
