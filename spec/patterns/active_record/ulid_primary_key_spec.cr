require "../../spec_helper"

# Schema for ULID primary key tests
UlidTestDB = CQL::Schema.define(
  :ulid_test_db,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3:///tmp/ulid_pk_spec.db"
) do
  table :ulid_events do
    primary :id, String, auto_increment: false # ULID stored as TEXT
    text :event_type
    text :payload
    timestamps
  end
end

# Model with ULID (String) primary key
class UlidEvent
  include CQL::ActiveRecord::Model(String)

  db_context schema: UlidTestDB, table: :ulid_events

  property event_type : String = ""
  property payload : String = ""
  property created_at : Time?
  property updated_at : Time?

  def initialize
  end

  def initialize(@event_type : String, @payload : String)
  end
end

describe "ULID Primary Key Support" do
  before_all do
    UlidTestDB.ulid_events.drop! rescue nil
    UlidTestDB.ulid_events.create!
  end

  after_all do
    UlidTestDB.ulid_events.drop! rescue nil
  end

  # Clean up data between tests
  before_each do
    UlidTestDB.exec("DELETE FROM ulid_events")
  end

  describe ".create!" do
    context "with named arguments" do
      it "creates a record with a ULID primary key" do
        event = UlidEvent.create!(
          event_type: "user.created",
          payload: "{\"user_id\": 1}",
          created_at: Time.utc,
          updated_at: Time.utc
        )

        event.id.should_not be_nil
        event.id.should be_a(String)
        event.id!.size.should eq(26) # ULID is 26 characters
        event.event_type.should eq("user.created")
      end

      it "generates sortable ULIDs" do
        event1 = UlidEvent.create!(
          event_type: "event1",
          payload: "{}",
          created_at: Time.utc,
          updated_at: Time.utc
        )

        sleep 1.millisecond # Ensure time difference

        event2 = UlidEvent.create!(
          event_type: "event2",
          payload: "{}",
          created_at: Time.utc,
          updated_at: Time.utc
        )

        # ULIDs should be sortable by creation time
        (event2.id! > event1.id!).should be_true
      end

      it "generates unique ULIDs for each record" do
        events = 10.times.map do |i|
          UlidEvent.create!(
            event_type: "event#{i}",
            payload: "{}",
            created_at: Time.utc,
            updated_at: Time.utc
          )
        end.to_a

        ids = events.map(&.id!)
        ids.uniq.size.should eq(10)
      end
    end

    context "with hash attributes" do
      it "creates a record with a ULID primary key" do
        attrs = {
          :event_type => "order.placed",
          :payload    => "{\"order_id\": 123}",
          :created_at => Time.utc,
          :updated_at => Time.utc,
        } of Symbol => DB::Any

        event = UlidEvent.create!(attrs)

        event.id.should_not be_nil
        event.id!.size.should eq(26)
        event.event_type.should eq("order.placed")
      end
    end

    context "with model instance" do
      it "creates a record and sets the ULID on the instance" do
        event = UlidEvent.new("payment.received", "{\"amount\": 99.99}")
        event.created_at = Time.utc
        event.updated_at = Time.utc

        created = UlidEvent.create!(event)

        created.id.should_not be_nil
        event.id.should eq(created.id)
        event.id!.size.should eq(26)
      end
    end
  end

  describe "#create!" do
    it "creates a record using instance method" do
      event = UlidEvent.new("item.shipped", "{\"tracking\": \"ABC123\"}")
      event.created_at = Time.utc
      event.updated_at = Time.utc

      event.create!

      event.id.should_not be_nil
      event.id!.size.should eq(26)
      event.persisted?.should be_true
    end
  end

  describe ".find" do
    it "finds a record by ULID" do
      event = UlidEvent.create!(
        event_type: "findable.event",
        payload: "{\"data\": \"test\"}",
        created_at: Time.utc,
        updated_at: Time.utc
      )

      found = UlidEvent.find!(event.id!)

      found.id.should eq(event.id)
      found.event_type.should eq("findable.event")
    end
  end

  describe ".find_or_create_by" do
    it "creates a new record if not found" do
      event = UlidEvent.find_or_create_by(
        event_type: "unique.event",
        payload: "{}",
        created_at: Time.utc,
        updated_at: Time.utc
      )

      event.id.should_not be_nil
      event.id!.size.should eq(26)
    end

    it "returns existing record if found" do
      existing = UlidEvent.create!(
        event_type: "existing.event",
        payload: "{}",
        created_at: Time.utc,
        updated_at: Time.utc
      )

      found = UlidEvent.find_or_create_by(event_type: "existing.event")

      found.id.should eq(existing.id)
    end
  end

  describe "ULID format validation" do
    it "generates valid ULID format (Crockford Base32)" do
      event = UlidEvent.create!(
        event_type: "test",
        payload: "{}",
        created_at: Time.utc,
        updated_at: Time.utc
      )

      # ULID should only contain valid Crockford Base32 characters
      # Crockford's Base32: 0-9A-Z excluding I, L, O, U
      event.id!.should match(/^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{26}$/)
    end

    it "generates 26-character IDs" do
      5.times do |i|
        event = UlidEvent.create!(
          event_type: "length_test_#{i}",
          payload: "{}",
          created_at: Time.utc,
          updated_at: Time.utc
        )

        event.id!.size.should eq(26)
      end
    end
  end

  describe "multiple record creation" do
    it "generates unique ULIDs for 20 records" do
      events = 20.times.map do |i|
        UlidEvent.create!(
          event_type: "bulk_event_#{i}",
          payload: "{\"index\": #{i}}",
          created_at: Time.utc,
          updated_at: Time.utc
        )
      end.to_a

      ids = events.map(&.id!)
      ids.uniq.size.should eq(20)
    end
  end
end
