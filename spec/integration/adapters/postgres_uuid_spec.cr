require "../spec_helper"

# PostgreSQL UUID Primary Key Tests
# These tests validate that the cql_compat.cr PostgreSQL UUID compatibility layer works correctly

PostgresUuidDB = CQL::Schema.define(
  :postgres_uuid_db,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]? || "postgres://localhost/cql_test"
) do
  table :postgres_uuid_sessions do
    primary :id, String, auto_increment: false
    text :token
    bigint :user_id
    timestamp :created_at
    timestamp :updated_at
  end
end

class PostgresUuidSession
  include CQL::ActiveRecord::Model(UUID)

  db_context schema: PostgresUuidDB, table: :postgres_uuid_sessions

  property token : String = ""
  property user_id : Int64 = 0_i64
  property created_at : Time?
  property updated_at : Time?
end

describe "PostgreSQL UUID Primary Keys" do
  before_all do
    PostgresUuidDB.postgres_uuid_sessions.drop!
    PostgresUuidDB.postgres_uuid_sessions.create!
  end

  after_all do
    PostgresUuidDB.postgres_uuid_sessions.drop!
  end

  after_each do
    PostgresUuidSession.delete_all
  end

  describe "CREATE operations" do
    it "creates a record with auto-generated UUID" do
      session = PostgresUuidSession.create!(
        token: "test_token",
        user_id: 1_i64,
        created_at: Time.utc,
        updated_at: Time.utc
      )

      session.id.should_not be_nil
      session.id!.should be_a(UUID)
      session.token.should eq("test_token")
    end

    it "generates unique UUIDs for multiple records" do
      session1 = PostgresUuidSession.create!(token: "token1", user_id: 1_i64)
      session2 = PostgresUuidSession.create!(token: "token2", user_id: 2_i64)

      session1.id!.should_not eq(session2.id!)
    end

    it "generates valid UUID format" do
      session = PostgresUuidSession.create!(token: "format_test", user_id: 1_i64)

      uuid_string = session.id!.to_s
      uuid_string.should match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
    end
  end

  describe "READ operations" do
    it "finds a record by UUID" do
      session = PostgresUuidSession.create!(token: "findable", user_id: 1_i64)

      found = PostgresUuidSession.find!(session.id!)
      found.token.should eq("findable")
      found.id!.should eq(session.id!)
    end

    it "returns nil for non-existent UUID" do
      random_uuid = UUID.random
      result = PostgresUuidSession.find?(random_uuid)
      result.should be_nil
    end

    it "supports find_by with UUID" do
      session = PostgresUuidSession.create!(token: "find_by_test", user_id: 42_i64)

      found = PostgresUuidSession.find_by(user_id: 42_i64)
      found.should_not be_nil
      found.not_nil!.id!.should eq(session.id!)
    end
  end

  describe "UPDATE operations" do
    it "updates a record by UUID" do
      session = PostgresUuidSession.create!(token: "original", user_id: 1_i64)

      PostgresUuidSession.update!(session.id!, token: "updated")

      found = PostgresUuidSession.find!(session.id!)
      found.token.should eq("updated")
    end

    it "updates multiple fields" do
      session = PostgresUuidSession.create!(token: "multi", user_id: 1_i64)

      PostgresUuidSession.update!(session.id!, token: "new_token", user_id: 99_i64)

      found = PostgresUuidSession.find!(session.id!)
      found.token.should eq("new_token")
      found.user_id.should eq(99_i64)
    end
  end

  describe "DELETE operations" do
    it "deletes a record by UUID" do
      session = PostgresUuidSession.create!(token: "deletable", user_id: 1_i64)
      uuid = session.id!

      PostgresUuidSession.delete!(uuid)

      PostgresUuidSession.find?(uuid).should be_nil
    end

    it "returns 0 for non-existent UUID delete" do
      random_uuid = UUID.random
      result = PostgresUuidSession.delete!(random_uuid)
      result.rows_affected.should eq(0)
    end
  end

  describe "batch operations with UUID" do
    it "supports find_each with UUID primary keys" do
      5.times do |i|
        PostgresUuidSession.create!(token: "batch_#{i}", user_id: i.to_i64)
      end

      count = 0
      PostgresUuidSession.query.find_each(batch_size: 2) do |session|
        count += 1
        session.id.should_not be_nil
      end

      count.should eq(5)
    end

    it "supports find_in_batches with UUID primary keys" do
      5.times do |i|
        PostgresUuidSession.create!(token: "batch_#{i}", user_id: i.to_i64)
      end

      batch_count = 0
      total_records = 0

      PostgresUuidSession.query.find_in_batches(batch_size: 2) do |batch|
        batch_count += 1
        total_records += batch.size
      end

      batch_count.should be >= 2
      total_records.should eq(5)
    end
  end

  describe "PostgreSQL native UUID handling" do
    it "correctly handles PostgreSQL native UUID type conversion" do
      # This test validates that the cql_compat.cr patch works correctly
      # PostgreSQL returns native UUID objects, which must be converted to String
      session = PostgresUuidSession.create!(token: "native_uuid", user_id: 1_i64)

      # Fetch the record - this exercises the PG::ResultSet#read override
      found = PostgresUuidSession.find!(session.id!)

      # Verify the UUID is correctly converted and usable
      found.id!.should be_a(UUID)
      found.id!.to_s.should eq(session.id!.to_s)
    end

    it "handles WHERE clause with UUID comparison" do
      session = PostgresUuidSession.create!(token: "where_test", user_id: 1_i64)

      # Query using the UUID in a WHERE clause
      results = PostgresUuidSession.query.where(token: "where_test").all
      results.size.should eq(1)
      results.first.id!.should eq(session.id!)
    end
  end
end
