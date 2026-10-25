require "./spec_helper"

InsertAllDB = CQL::Schema.define(:insert_all_db, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("insert_all.db")) do
  table :insert_all_items do
    primary :id, Int64, auto_increment: true
    text :title
    integer :quantity
    text :note, null: true
  end

  table :insert_all_stamped_items do
    primary :id, Int64, auto_increment: true
    text :title
    timestamps
  end
end

class InsertAllItem
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: InsertAllDB, table: :insert_all_items

  class_property saved_titles = [] of String

  property title : String = ""
  property quantity : Int32 = 0
  property note : String? = nil

  validate :title, presence: true, message: "Title is required"
  validate :quantity, gt: 0, message: "Quantity must be positive"

  before_save :remember_title

  def initialize
  end

  def remember_title
    self.class.saved_titles << title
    true
  end
end

class InsertAllStampedItem
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: InsertAllDB, table: :insert_all_stamped_items

  property title : String = ""
  property created_at : Time?
  property updated_at : Time?
end

private alias InsertAllRow = Hash(Symbol, DB::Any)

private def item_rows(count : Int32) : Array(InsertAllRow)
  (1..count).map do |i|
    InsertAllRow{:title => "item #{i}".as(DB::Any), :quantity => i.as(DB::Any), :note => "note #{i}".as(DB::Any)}
  end
end

# INSERT statements (SQL and bound-value count) the block executed, in order.
private def insert_statements(& : ->) : Array({String, Int32})
  statements = [] of {String, Int32}
  subscription = "insert_all_spec_#{Random::Secure.hex(4)}"
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

describe "Model.insert_all" do
  before_each do
    InsertAllDB.insert_all_items.drop!
    InsertAllDB.insert_all_items.create!
    InsertAllDB.insert_all_stamped_items.drop!
    InsertAllDB.insert_all_stamped_items.create!
    InsertAllItem.saved_titles.clear
  end

  after_all do
    InsertAllDB.insert_all_items.drop!
    InsertAllDB.insert_all_stamped_items.drop!
  end

  it "inserts every row, returns the count and stores the given values" do
    inserted = InsertAllItem.insert_all(item_rows(3))

    inserted.should eq(3)
    stored = InsertAllItem.order(id: :asc).all
    stored.map(&.title).should eq(["item 1", "item 2", "item 3"])
    stored.map(&.quantity).should eq([1, 2, 3])
    stored.map(&.note).should eq(["note 1", "note 2", "note 3"])
  end

  it "accepts an array of named tuples" do
    inserted = InsertAllItem.insert_all([
      {title: "tuple a", quantity: 1, note: "x"},
      {title: "tuple b", quantity: 2, note: "y"},
    ])

    inserted.should eq(2)
    InsertAllItem.order(id: :asc).all.map(&.title).should eq(["tuple a", "tuple b"])
  end

  it "stores nil values" do
    rows = [InsertAllRow{:title => "nil note".as(DB::Any), :quantity => 1.as(DB::Any), :note => nil.as(DB::Any)}]

    InsertAllItem.insert_all(rows).should eq(1)

    InsertAllItem.all.first.note.should be_nil
  end

  it "returns 0 and runs no statement for an empty array" do
    result = 0
    statements = insert_statements { result = InsertAllItem.insert_all([] of InsertAllRow) }

    result.should eq(0)
    statements.should be_empty
    InsertAllItem.count.should eq(0)
  end

  describe "chunking" do
    it "splits rows into batch_size statements" do
      inserted = 0
      statements = insert_statements { inserted = InsertAllItem.insert_all(item_rows(5), batch_size: 2) }

      inserted.should eq(5)
      statements.size.should eq(3)
      statements.map(&.[1]).should eq([6, 6, 3])
      InsertAllItem.order(id: :asc).all.map(&.title).should eq((1..5).map { |i| "item #{i}" })
    end

    it "uses a single statement when the rows fit in one batch" do
      statements = insert_statements { InsertAllItem.insert_all(item_rows(5), batch_size: 5) }

      statements.size.should eq(1)
    end

    it "keeps every statement within the dialect's bind parameter limit by default" do
      limit = InsertAllItem.adapter.dialect.max_bind_params
      rows = item_rows(400)
      inserted = 0

      statements = insert_statements { inserted = InsertAllItem.insert_all(rows) }

      (400 * 3).should be > limit
      inserted.should eq(400)
      statements.size.should be >= 2
      statements.each { |(_, bound)| bound.should be <= limit }
      statements.sum(&.[1]).should eq(400 * 3)
      InsertAllItem.count.should eq(400)
    end

    it "rolls back earlier batches when a later batch fails" do
      rows = item_rows(4)
      rows[3][:title] = nil

      expect_raises(Exception) { InsertAllItem.insert_all(rows, batch_size: 2) }

      InsertAllItem.count.should eq(0)
    end

    it "rejects a batch_size that binds more values than the dialect allows" do
      limit = InsertAllItem.adapter.dialect.max_bind_params

      statements = insert_statements do
        expect_raises(ArgumentError, /binds more than/) { InsertAllItem.insert_all(item_rows(2), batch_size: limit) }
      end

      statements.should be_empty
    end

    it "rolls back with an enclosing transaction" do
      InsertAllDB.transaction do |tx|
        InsertAllItem.insert_all(item_rows(5), batch_size: 2)
        InsertAllItem.count.should eq(5)
        tx.rollback
      end

      InsertAllItem.count.should eq(0)
    end

    it "rejects a non-positive batch_size before running a statement" do
      statements = insert_statements do
        expect_raises(ArgumentError) { InsertAllItem.insert_all(item_rows(2), batch_size: 0) }
      end

      statements.should be_empty
      InsertAllItem.count.should eq(0)
    end
  end

  describe "skipping validations and callbacks" do
    it "inserts rows that fail the model validations" do
      invalid = InsertAllItem.new
      invalid.title = ""
      invalid.quantity = -1
      invalid.valid?.should be_false

      rows = [InsertAllRow{:title => "".as(DB::Any), :quantity => -1.as(DB::Any), :note => nil.as(DB::Any)}]

      InsertAllItem.insert_all(rows).should eq(1)

      stored = InsertAllItem.all.first
      stored.title.should eq("")
      stored.quantity.should eq(-1)
    end

    it "does not run save callbacks" do
      InsertAllItem.insert_all(item_rows(3))

      InsertAllItem.saved_titles.should be_empty
    end
  end

  describe "validating the rows" do
    it "raises ArgumentError before any statement when key sets differ" do
      rows = item_rows(3)
      rows << InsertAllRow{:title => "odd".as(DB::Any), :quantity => 9.as(DB::Any)}

      statements = insert_statements do
        expect_raises(ArgumentError) { InsertAllItem.insert_all(rows, batch_size: 2) }
      end

      statements.should be_empty
      InsertAllItem.count.should eq(0)
    end

    it "rejects rows without columns" do
      expect_raises(ArgumentError, /at least one column/) { InsertAllItem.insert_all([InsertAllRow.new]) }
    end

    it "drops a nil id so the database assigns one" do
      rows = item_rows(2).map(&.merge({:id => nil.as(DB::Any)}))

      InsertAllItem.insert_all(rows).should eq(2)

      InsertAllItem.all.compact_map(&.id).size.should eq(2)
    end

    it "accepts rows whose keys are in a different order" do
      rows = [
        InsertAllRow{:title => "a".as(DB::Any), :quantity => 1.as(DB::Any)},
        InsertAllRow{:quantity => 2.as(DB::Any), :title => "b".as(DB::Any)},
      ]

      InsertAllItem.insert_all(rows).should eq(2)

      InsertAllItem.order(id: :asc).all.map { |item| {item.title, item.quantity} }.should eq([{"a", 1}, {"b", 2}])
    end

    it "raises when a key is not a column of the table" do
      rows = [InsertAllRow{:title => "a".as(DB::Any), :nope => 1.as(DB::Any)}]

      statements = insert_statements { expect_raises(ArgumentError, /nope/) { InsertAllItem.insert_all(rows) } }

      statements.should be_empty
    end
  end

  describe "timestamps" do
    it "fills created_at and updated_at when a row omits them" do
      before = Time.utc - 1.second
      rows = [InsertAllRow{:title => "stamped".as(DB::Any)}]

      InsertAllStampedItem.insert_all(rows).should eq(1)

      stored = InsertAllStampedItem.all.first
      stored.created_at.not_nil!.should be >= before
      stored.updated_at.not_nil!.should be >= before
    end

    it "fills nil timestamps and keeps given ones row by row" do
      given = Time.utc(2020, 1, 2, 3, 4, 5)
      rows = [
        InsertAllRow{:title => "nil".as(DB::Any), :created_at => nil.as(DB::Any), :updated_at => nil.as(DB::Any)},
        InsertAllRow{:title => "given".as(DB::Any), :created_at => given.as(DB::Any), :updated_at => given.as(DB::Any)},
      ]

      InsertAllStampedItem.insert_all(rows)

      stored = InsertAllStampedItem.order(id: :asc).all
      stored[0].created_at.not_nil!.should be > given
      stored[1].created_at.should eq(given)
    end

    it "keeps timestamps the row provides" do
      given = Time.utc(2020, 1, 2, 3, 4, 5)
      rows = [InsertAllRow{:title => "given".as(DB::Any), :created_at => given.as(DB::Any), :updated_at => given.as(DB::Any)}]

      InsertAllStampedItem.insert_all(rows)

      stored = InsertAllStampedItem.all.first
      stored.created_at.should eq(given)
      stored.updated_at.should eq(given)
    end

    it "leaves models without timestamp columns untouched" do
      statements = insert_statements { InsertAllItem.insert_all(item_rows(1)) }

      statements.first[0].should_not contain("created_at")
    end
  end
end
