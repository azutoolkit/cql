require "../spec_helper"

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

  it "bang variants return values" do
    users.call.first!(as: String).should eq("ada")
    users.call.where(name: "ada").get!(as: String).should eq("ada")
    users.call.all!(as: String).size.should eq(3)
  end

  it "first is nil on an empty result" do
    users.call.where(name: "nobody").first(as: String).should be_nil
  end
end
