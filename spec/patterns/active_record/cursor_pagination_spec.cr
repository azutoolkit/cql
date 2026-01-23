require "../../spec_helper"

# Cursor-based pagination tests
# Tests after_cursor, before_cursor, and paginate_by methods

CursorPaginationDB = CQL::Schema.define(
  :cursor_pagination_db,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://./spec/support/db/cursor_pagination.db"
) do
  table :cursor_test_records do
    primary :id, Int64, auto_increment: true
    text :name
    bigint :sort_order
    timestamp :created_at
  end
end

class CursorTestRecord
  include CQL::ActiveRecord::Model(Int64)

  db_context schema: CursorPaginationDB, table: :cursor_test_records

  property name : String = ""
  property sort_order : Int64 = 0_i64
  property created_at : Time?
end

describe "Cursor-based Pagination" do
  before_all do
    CursorPaginationDB.cursor_test_records.drop!
    CursorPaginationDB.cursor_test_records.create!
  end

  after_all do
    CursorPaginationDB.cursor_test_records.drop!
  end

  before_each do
    CursorTestRecord.delete_all
    # Create test records with sequential IDs
    10.times do |i|
      CursorTestRecord.create!(
        name: "Record #{i + 1}",
        sort_order: (i + 1).to_i64 * 10,
        created_at: Time.utc - (10 - i).hours
      )
    end
  end

  describe ".after_cursor" do
    it "returns records after the given cursor ID" do
      all_records = CursorTestRecord.query.order(:id).all
      cursor_id = all_records[4].id! # 5th record

      results = CursorTestRecord.after_cursor(cursor_id, limit: 3)

      results.size.should eq(3)
      results.all? { |r| r.id! > cursor_id }.should be_true
    end

    it "returns empty array when cursor is at the end" do
      all_records = CursorTestRecord.query.order(:id).all
      last_id = all_records.last.id!

      results = CursorTestRecord.after_cursor(last_id, limit: 10)

      results.should be_empty
    end

    it "returns records in ascending order by ID" do
      all_records = CursorTestRecord.query.order(:id).all
      first_id = all_records.first.id!

      results = CursorTestRecord.after_cursor(first_id, limit: 5)

      results.size.should eq(5)
      ids = results.map(&.id!)
      ids.should eq(ids.sort)
    end

    it "respects the limit parameter" do
      all_records = CursorTestRecord.query.order(:id).all
      first_id = all_records.first.id!

      results = CursorTestRecord.after_cursor(first_id, limit: 2)

      results.size.should eq(2)
    end
  end

  describe ".before_cursor" do
    it "returns records before the given cursor ID" do
      all_records = CursorTestRecord.query.order(:id).all
      cursor_id = all_records[5].id! # 6th record

      results = CursorTestRecord.before_cursor(cursor_id, limit: 3)

      results.size.should eq(3)
      results.all? { |r| r.id! < cursor_id }.should be_true
    end

    it "returns empty array when cursor is at the beginning" do
      all_records = CursorTestRecord.query.order(:id).all
      first_id = all_records.first.id!

      results = CursorTestRecord.before_cursor(first_id, limit: 10)

      results.should be_empty
    end

    it "returns records in ascending order (reversed from query)" do
      all_records = CursorTestRecord.query.order(:id).all
      last_id = all_records.last.id!

      results = CursorTestRecord.before_cursor(last_id, limit: 5)

      results.size.should eq(5)
      ids = results.map(&.id!)
      ids.should eq(ids.sort)
    end

    it "respects the limit parameter" do
      all_records = CursorTestRecord.query.order(:id).all
      last_id = all_records.last.id!

      results = CursorTestRecord.before_cursor(last_id, limit: 2)

      results.size.should eq(2)
    end
  end

  describe ".paginate_by" do
    it "paginates by a custom column" do
      results = CursorTestRecord.paginate_by(:sort_order, 30_i64, limit: 3)

      results.size.should eq(3)
      results.all? { |r| r.sort_order > 30 }.should be_true
    end

    it "returns records in order of the specified column" do
      results = CursorTestRecord.paginate_by(:sort_order, 0_i64, limit: 5)

      sort_orders = results.map(&.sort_order)
      sort_orders.should eq(sort_orders.sort)
    end

    it "returns empty when no records match" do
      results = CursorTestRecord.paginate_by(:sort_order, 1000_i64, limit: 10)

      results.should be_empty
    end
  end

  describe "pagination workflow" do
    it "supports forward pagination through all records" do
      collected_ids = [] of Int64
      cursor_id = 0_i64

      loop do
        page = CursorTestRecord.after_cursor(cursor_id, limit: 3)
        break if page.empty?

        page.each { |r| collected_ids << r.id! }
        cursor_id = page.last.id!
      end

      collected_ids.size.should eq(10)
      collected_ids.should eq(collected_ids.sort)
    end

    it "supports backward pagination through all records" do
      all_records = CursorTestRecord.query.order(:id).all
      cursor_id = all_records.last.id! + 1 # Start after last record

      collected_ids = [] of Int64

      loop do
        page = CursorTestRecord.before_cursor(cursor_id, limit: 3)
        break if page.empty?

        page.reverse_each { |r| collected_ids.unshift(r.id!) }
        cursor_id = page.first.id!
      end

      collected_ids.size.should eq(10)
      collected_ids.should eq(collected_ids.sort)
    end
  end
end
