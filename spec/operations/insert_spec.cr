require "../spec_helper"
require "log/spec"

private INSERT_FAILURE_MARKER = "secret-marker-42"

# A table of its own: other specs change the shared schemas' declarations.
private InsertFailureDB = CQL::Schema.define(:insert_failure_db, adapter: CQL::Adapter::Postgres, uri: postgres_database_url) do
  table :insert_failures do
    primary :id, Int64, auto_increment: true
    bigint :amount
  end
end

# The log lines (message and exception message) that mention the failure while *block* raises *error*.
private def leaked_log_lines(error : T.class, & : ->) forall T
  backend = Log::MemoryBackend.new
  Log.builder.bind("*", :trace, backend)
  leaks = {"Insert failed", INSERT_FAILURE_MARKER, expect_raises(error) { yield }.message.to_s}.reject(&.empty?)
  lines = backend.entries.map { |entry| "#{entry.message} #{entry.exception.try(&.message)}" }
  lines.select { |line| leaks.any? { |leak| line.includes?(leak) } }
ensure
  Log.builder.unbind("*", :trace, backend) if backend
end

describe CQL::Insert do
  it "creates Insert Into query" do
    insert_query = Northwind
      .insert
      .into(:users)
      .values(name: "John", email: "john@example.com")
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      INSERT INTO users (name, email) VALUES (?, ?)
      SQL

    insert_query.should eq({output, ["John", "john@example.com"]})
  end

  it "creates Insert Into query with multiple rows" do
    insert_query = Northwind.insert.into(:users)
      .values(name: "John", email: "john@example.com")
      .values(name: "Jane", email: "jane@example.com")
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
    INSERT INTO users (name, email)
    VALUES (?, ?), (?, ?)
    SQL

    insert_query.should eq({output, ["John", "john@example.com", "Jane", "jane@example.com"]})
  end

  it "creates Insert Into query with Array(Hash(Symbol, DB::Any))" do
    insert_query = Northwind.insert.into(:users)
      .values(
        [{:name => "John", :email => "john@doe.com"},
         {:name => "Jane", :email => "jane@doe.com"}])
      .to_sql
    output = <<-SQL.gsub(/\n/, " ").strip
      INSERT INTO users (name, email)
      VALUES (?, ?), (?, ?)
      SQL

    insert_query.should eq({output, ["John", "john@doe.com", "Jane", "jane@doe.com"]})
  end

  it "creates Insert Into query with returning clause" do
    insert_query = Northwind.insert.into(:users)
      .values(name: "John", email: "jane@example.com")
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      INSERT INTO users (name, email) VALUES (?, ?)
      SQL

    insert_query.should eq({output, ["John", "jane@example.com"]})
  end

  it "creates Insert Into with select query" do
    select_query = Northwind.query.from(:users)
      .select(:name, :email)
      .where { users.id == 1 }

    insert_query = Northwind.insert.into(:users)
      .query(select_query)
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      INSERT INTO users (name, email)
      SELECT users.name, users.email
      FROM users WHERE users.id = ?
      SQL

    insert_query.should eq({output, [1]})
  end

  it "keeps RETURNING on an INSERT ... SELECT" do
    copy = Northwind.insert.into(:users)
      .query(Northwind.query.from(:users).select(:name, :email).where { users.id == 1 })
      .back(:id)
    pg = Expression::Generator.new(CQL::Adapter::Postgres)

    copy.to_sql(pg).should eq({"INSERT INTO users (name, email) SELECT users.name, users.email FROM users WHERE users.id = $1 RETURNING users.id", [1] of DB::Any})
  end

  it "inserts and gets the last inserted id" do
    Northwind.users.drop! rescue nil
    Northwind.users.create!

    last_id = Northwind.insert.into(:users)
      .values(name: "John", email: "john@example.com", age: 20)
      .last_insert_id

    last_id.should eq(1)

    Northwind.users.drop!
  end

  it "inserts multiple records and gets the last inserted id" do
    Northwind.users.drop! rescue nil
    Northwind.users.create!

    last_id = Northwind.insert.into(:users)
      .values(
        [{:name => "John", :email => "john@doe.com", :age => 30},
         {:name => "Jane", :email => "jane@doe.com", :age => 30}])
      .last_insert_id

    last_id.should eq(2)

    Northwind.users.drop!
  end

  it "raises ArgumentError for a table the schema does not know" do
    expect_raises(ArgumentError, "Table nope not found") { Northwind.insert.into(:nope) }
  end

  describe "a failed insert" do
    it "raises on #commit (SQLite) and reports the error to telemetry without logging it" do
      Northwind.users.drop! rescue nil
      Northwind.users.create!
      duplicate = -> { Northwind.insert.into(:users).values(id: 1, name: INSERT_FAILURE_MARKER, email: INSERT_FAILURE_MARKER, age: 1).commit }
      duplicate.call
      errors = [] of Exception?
      CQL::Telemetry.subscribe("insert_spec_failure") { |event| errors << event.error }
      leaks = leaked_log_lines(SQLite3::Exception) { duplicate.call }
      errors.compact.size.should eq 1
      leaks.should be_empty
    ensure
      CQL::Telemetry.unsubscribe("insert_spec_failure")
      Northwind.users.drop! rescue nil
    end

    it "raises on #get (PostgreSQL) without logging the driver's message" do
      require_postgres!
      InsertFailureDB.insert_failures.drop! rescue nil
      InsertFailureDB.insert_failures.create!
      insert = InsertFailureDB.insert.into(:insert_failures).values(amount: INSERT_FAILURE_MARKER).back(:id)
      leaked_log_lines(PQ::PQError) { insert.get(Int64) }.should be_empty
    ensure
      InsertFailureDB.insert_failures.drop! rescue nil
    end
  end
end
