require "../spec_helper"

private struct NameAndAge
  include DB::Serializable

  getter name : String
  getter age : Int32
end

describe CQL::Executable do
  before_each do
    UserDB.users.create!
    %w[ada grace linus].each_with_index do |name, i|
      UserDB.insert.into(:users).values(name: name, email: "#{name}@example.com", age: 20 + i, password: "pw").commit
    end
  end

  after_each { UserDB.users.drop! }

  users = -> { UserDB.query.from(:users).select(:name).order(id: :asc) }

  it "is included by Query" do
    users.call.should be_a(CQL::Executable)
  end

  it "all returns every row" do
    users.call.all(as: String).should eq(%w[ada grace linus])
  end

  it "get returns the single matching row, or nil, and rejects several" do
    users.call.where(name: "ada").get(as: String).should eq("ada")
    users.call.where(name: "nobody").get(as: String).should be_nil
    expect_raises(DB::Error, /more than one row/) { users.call.get(as: String) }
  end

  it "first returns one row without changing the query" do
    query = users.call
    sql_before = query.to_sql

    query.first(as: String).should eq("ada")
    query.to_sql.should eq(sql_before)
  end

  it "first respects an existing offset" do
    users.call.offset(1).first(as: String).should eq("grace")
  end

  it "each yields every row" do
    names = [] of String
    users.call.each(as: String) { |name| names << name }

    names.should eq(%w[ada grace linus])
  end

  describe "#each with a yielding block" do
    it "yields structs and honors the query's order" do
      rows = [] of NameAndAge
      UserDB.query.from(:users).select(:name, :age).order(age: :desc).each(as: NameAndAge) { |row| rows << row }

      rows.map { |row| {row.name, row.age} }.should eq([{"linus", 22}, {"grace", 21}, {"ada", 20}])
    end

    it "stops at a break and releases the connection" do
      seen = [] of String
      users.call.each(as: String) do |name|
        seen << name
        break if seen.size == 2
      end

      seen.should eq(%w[ada grace])
      UserDB.pool_stats.in_flight.should eq(0)
      users.call.all(as: String).should eq(%w[ada grace linus])
    end

    it "propagates an exception from the block and releases the connection" do
      expect_raises(Exception, "boom") do
        users.call.each(as: String) { |_| raise "boom" }
      end

      UserDB.pool_stats.in_flight.should eq(0)
      users.call.all(as: String).should eq(%w[ada grace linus])
    end
  end

  it "bang variants return values" do
    users.call.first!(as: String).should eq("ada")
    users.call.where(name: "ada").get!(as: String).should eq("ada")
    users.call.all!(as: String).size.should eq(3)
  end

  it "get! raises DB::NoResultsError on an empty result" do
    expect_raises(DB::NoResultsError, "The query returned no row") do
      users.call.where(name: "nobody").get!(as: String)
    end
  end

  it "first is nil on an empty result" do
    users.call.where(name: "nobody").first(as: String).should be_nil
  end
end
