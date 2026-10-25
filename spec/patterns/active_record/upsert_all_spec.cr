require "./spec_helper"

UpsertAllDB = CQL::Schema.define(:upsert_all_db, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("upsert_all.db")) do
  table :upsert_all_products do
    primary :id, Int64, auto_increment: true
    text :sku, unique: true
    text :title
    integer :quantity
  end

  table :upsert_all_stamped_products do
    primary :id, Int64, auto_increment: true
    text :sku, unique: true
    text :title
    timestamps
  end

  table :upsert_all_tags do
    primary :id, Int64, auto_increment: true
    text :label, unique: true
  end
end

class UpsertAllTag
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UpsertAllDB, table: :upsert_all_tags

  property label : String = ""
end

class UpsertAllProduct
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UpsertAllDB, table: :upsert_all_products

  property sku : String = ""
  property title : String = ""
  property quantity : Int32 = 0

  def initialize
  end
end

class UpsertAllStampedProduct
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UpsertAllDB, table: :upsert_all_stamped_products

  property sku : String = ""
  property title : String = ""
  property created_at : Time?
  property updated_at : Time?
end

private alias UpsertRow = Hash(Symbol, DB::Any)

private def product_row(sku : String, title : String, quantity : Int32) : UpsertRow
  UpsertRow{:sku => sku.as(DB::Any), :title => title.as(DB::Any), :quantity => quantity.as(DB::Any)}
end

private def seed_products
  UpsertAllProduct.insert_all([product_row("a", "Apple", 1), product_row("b", "Banana", 2)])
end

private def stored_products : Array({String, String, Int32})
  UpsertAllProduct.order(sku: :asc).all.map { |product| {product.sku, product.title, product.quantity} }
end

# INSERT statements (SQL and bound-value count) the block executed, in order.
private def upsert_statements(& : ->) : Array({String, Int32})
  statements = [] of {String, Int32}
  subscription = "upsert_all_spec_#{Random::Secure.hex(4)}"
  CQL::Telemetry.subscribe(subscription) do |event|
    statements << {event.sql, event.param_count} if event.operation == :insert
  end
  begin
    yield
  ensure
    CQL::Telemetry.unsubscribe(subscription)
  end
  statements
end

describe "Model.upsert_all" do
  before_each do
    UpsertAllDB.upsert_all_products.drop!
    UpsertAllDB.upsert_all_products.create!
    UpsertAllDB.upsert_all_stamped_products.drop!
    UpsertAllDB.upsert_all_stamped_products.create!
  end

  after_all do
    UpsertAllDB.upsert_all_products.drop!
    UpsertAllDB.upsert_all_stamped_products.drop!
  end

  it "updates rows matched on the conflict target and inserts the others in one statement" do
    seed_products
    rows = [product_row("b", "Banana v2", 20), product_row("c", "Cherry", 30)]

    statements = upsert_statements { UpsertAllProduct.upsert_all(rows, on_conflict: :sku) }

    statements.size.should eq(1)
    statements.first[0].should contain("ON CONFLICT")
    stored_products.should eq([{"a", "Apple", 1}, {"b", "Banana v2", 20}, {"c", "Cherry", 30}])
  end

  it "returns the rows affected as the database reports them" do
    seed_products

    UpsertAllProduct.upsert_all([product_row("b", "Banana v2", 20), product_row("c", "Cherry", 30)], on_conflict: :sku).should eq(2)
  end

  it "accepts the conflict target as an array" do
    seed_products

    UpsertAllProduct.upsert_all([product_row("a", "Apple v2", 10)], on_conflict: [:sku])

    stored_products.should eq([{"a", "Apple v2", 10}, {"b", "Banana", 2}])
  end

  it "runs no statement for an empty array" do
    result = -1
    statements = upsert_statements { result = UpsertAllProduct.upsert_all([] of UpsertRow, on_conflict: :sku).to_i }

    result.should eq(0)
    statements.should be_empty
  end

  it "chunks into batch_size statements and keeps updating existing rows" do
    seed_products
    rows = [product_row("a", "A2", 10), product_row("b", "B2", 20), product_row("c", "C2", 30)]

    statements = upsert_statements { UpsertAllProduct.upsert_all(rows, on_conflict: :sku, batch_size: 2) }

    statements.size.should eq(2)
    stored_products.should eq([{"a", "A2", 10}, {"b", "B2", 20}, {"c", "C2", 30}])
  end

  describe "update:" do
    it "changes only the listed columns on conflict" do
      seed_products

      UpsertAllProduct.upsert_all([product_row("a", "Renamed", 99), product_row("c", "Cherry", 3)], on_conflict: :sku, update: [:quantity])

      stored_products.should eq([{"a", "Apple", 99}, {"b", "Banana", 2}, {"c", "Cherry", 3}])
    end

    it "leaves existing rows unchanged for an empty list but still inserts new rows" do
      seed_products

      UpsertAllProduct.upsert_all([product_row("a", "Renamed", 99), product_row("c", "Cherry", 3)], on_conflict: :sku, update: [] of Symbol)

      stored_products.should eq([{"a", "Apple", 1}, {"b", "Banana", 2}, {"c", "Cherry", 3}])
    end

    it "never overwrites the id of an existing row by default" do
      seed_products
      original = UpsertAllProduct.find_by!(sku: "a").id
      row = product_row("a", "Apple v2", 7).merge({:id => 999_i64.as(DB::Any)})

      UpsertAllProduct.upsert_all([row], on_conflict: :sku)

      updated = UpsertAllProduct.find_by!(sku: "a")
      updated.id.should eq(original)
      updated.title.should eq("Apple v2")
    end
  end

  describe "timestamps" do
    it "keeps created_at and refreshes updated_at on update" do
      old = Time.utc(2020, 1, 2, 3, 4, 5)
      UpsertAllStampedProduct.insert_all([
        UpsertRow{:sku => "a".as(DB::Any), :title => "Apple".as(DB::Any), :created_at => old.as(DB::Any), :updated_at => old.as(DB::Any)},
      ])
      before = Time.utc - 1.second

      UpsertAllStampedProduct.upsert_all([
        UpsertRow{:sku => "a".as(DB::Any), :title => "Apple v2".as(DB::Any)},
        UpsertRow{:sku => "b".as(DB::Any), :title => "Banana".as(DB::Any)},
      ], on_conflict: :sku)

      stored = UpsertAllStampedProduct.order(sku: :asc).all
      stored.map(&.title).should eq(["Apple v2", "Banana"])
      stored[0].created_at.should eq(old)
      stored[0].updated_at.not_nil!.should be >= before
      stored[1].created_at.not_nil!.should be >= before
      stored[1].updated_at.not_nil!.should be >= before
    end

    it "keeps updated_at when update: leaves it out and the row conflicts" do
      old = Time.utc(2020, 1, 2, 3, 4, 5)
      UpsertAllStampedProduct.insert_all([
        UpsertRow{:sku => "a".as(DB::Any), :title => "Apple".as(DB::Any), :created_at => old.as(DB::Any), :updated_at => old.as(DB::Any)},
      ])

      UpsertAllStampedProduct.upsert_all([UpsertRow{:sku => "a".as(DB::Any), :title => "Apple v2".as(DB::Any)}], on_conflict: :sku, update: [] of Symbol)

      stored = UpsertAllStampedProduct.all.first
      stored.title.should eq("Apple")
      stored.updated_at.should eq(old)
    end
  end

  describe "generated SQL" do
    stamped_upsert = ->(adapter : CQL::Adapter) do
      rows = [UpsertRow{:sku => "a".as(DB::Any), :title => "A".as(DB::Any)}]
      conflict = CQL::ActiveRecord::BulkInsert::Conflict.new([:sku])
      statement = CQL::ActiveRecord::BulkInsert.new(UpsertAllDB, :upsert_all_stamped_products, rows, conflict: conflict).first_statement.not_nil!
      statement.to_sql(Expression::Generator.new(adapter))
    end

    it "updates every inserted column but the target and created_at on PostgreSQL" do
      sql, params = stamped_upsert.call(CQL::Adapter::Postgres)

      sql.should eq("INSERT INTO upsert_all_stamped_products (sku, title, created_at, updated_at) VALUES ($1, $2, $3, $4) " \
                    "ON CONFLICT (sku) DO UPDATE SET title = EXCLUDED.title, updated_at = EXCLUDED.updated_at")
      params.size.should eq(4)
    end

    it "uses ON DUPLICATE KEY UPDATE with VALUES() on MySQL" do
      sql, _ = stamped_upsert.call(CQL::Adapter::MySql)

      sql.should eq("INSERT INTO upsert_all_stamped_products (sku, title, created_at, updated_at) VALUES (?, ?, ?, ?) " \
                    "ON DUPLICATE KEY UPDATE title = VALUES(title), updated_at = VALUES(updated_at)")
    end
  end

  it "skips existing rows when the rows insert nothing but the conflict target" do
    UpsertAllDB.upsert_all_tags.drop!
    UpsertAllDB.upsert_all_tags.create!
    UpsertAllTag.upsert_all([{label: "a"}], on_conflict: :label)

    UpsertAllTag.upsert_all([{label: "a"}, {label: "b"}], on_conflict: :label).should eq(1)

    UpsertAllTag.order(label: :asc).all.map(&.label).should eq(["a", "b"])
  ensure
    UpsertAllDB.upsert_all_tags.drop!
  end

  it "ignores repeated column names" do
    seed_products

    UpsertAllProduct.upsert_all([product_row("a", "Apple", 5)], on_conflict: [:sku, :sku], update: [:quantity, :quantity])

    stored_products.should eq([{"a", "Apple", 5}, {"b", "Banana", 2}])
  end

  describe "validating the arguments" do
    it "raises ArgumentError before any statement when the conflict target is not a column" do
      statements = upsert_statements do
        expect_raises(ArgumentError, /nope/) { UpsertAllProduct.upsert_all([product_row("a", "A", 1)], on_conflict: :nope) }
      end

      statements.should be_empty
      UpsertAllProduct.count.should eq(0)
    end

    it "raises ArgumentError when the conflict target is not among the inserted columns" do
      rows = [UpsertRow{:title => "A".as(DB::Any), :quantity => 1.as(DB::Any)}]

      statements = upsert_statements do
        expect_raises(ArgumentError, /sku/) { UpsertAllProduct.upsert_all(rows, on_conflict: :sku) }
      end

      statements.should be_empty
    end

    it "raises ArgumentError for an empty conflict target" do
      expect_raises(ArgumentError) { UpsertAllProduct.upsert_all([product_row("a", "A", 1)], on_conflict: [] of Symbol) }
    end

    it "raises ArgumentError before any statement when an update column is not an inserted column" do
      rows = [UpsertRow{:sku => "a".as(DB::Any), :title => "A".as(DB::Any)}]

      statements = upsert_statements do
        expect_raises(ArgumentError, /quantity/) { UpsertAllProduct.upsert_all(rows, on_conflict: :sku, update: [:quantity]) }
      end

      statements.should be_empty
    end

    it "raises ArgumentError when an update column is not a column of the table" do
      expect_raises(ArgumentError, /nope/) { UpsertAllProduct.upsert_all([product_row("a", "A", 1)], on_conflict: :sku, update: [:nope]) }
    end

    it "applies the insert_all row checks" do
      rows = [product_row("a", "A", 1), UpsertRow{:sku => "b".as(DB::Any), :title => "B".as(DB::Any)}]

      statements = upsert_statements do
        expect_raises(ArgumentError) { UpsertAllProduct.upsert_all(rows, on_conflict: :sku) }
      end

      statements.should be_empty
      expect_raises(ArgumentError) { UpsertAllProduct.upsert_all([product_row("a", "A", 1)], on_conflict: :sku, batch_size: 0) }
    end
  end
end
