require "../spec_helper"

describe CQL::Update do
  it "creates Update query" do
    update_query = Northwind.update.table(:users)
      .set(name: "John", email: "john@example.com")
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      UPDATE users SET name = ?, email = ?
      SQL

    update_query.should eq({output, ["John", "john@example.com"]})
  end

  it "create update where query" do
    update_query = Northwind.update.table(:users)
      .set(name: "John", email: "john@example.com")
      .where { users.id == 1 }
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      UPDATE users SET name = ?, email = ?
      WHERE users.id = ?
      SQL
    update_query.should eq({output, ["John", "john@example.com", 1]})
  end

  it "handles array values in WHERE clause" do
    update_query = Northwind.update.table(:users)
      .set(name: "Updated", email: "updated@example.com")
      .where(id: [1, 2, 3])
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      UPDATE users SET name = ?, email = ?
      WHERE users.id IN (?, ?, ?)
      SQL
    update_query.should eq({output, ["Updated", "updated@example.com", 1, 2, 3]})
  end

  it "handles multiple array conditions in WHERE clause" do
    update_query = Northwind.update.table(:users)
      .set(name: "Updated", email: "updated@example.com")
      .where(id: [1, 2, 3], name: ["Alice", "Bob"])
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      UPDATE users SET name = ?, email = ?
      WHERE (users.id IN (?, ?, ?)) AND (users.name IN (?, ?))
      SQL
    update_query.should eq({output, ["Updated", "updated@example.com", 1, 2, 3, "Alice", "Bob"]})
  end

  it "handles array values with other conditions in WHERE clause" do
    update_query = Northwind.update.table(:users)
      .set(name: "Updated", email: "updated@example.com")
      .where(id: [1, 2, 3], age: 25)
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      UPDATE users SET name = ?, email = ?
      WHERE (users.id IN (?, ?, ?)) AND (users.age = ?)
      SQL
    update_query.should eq({output, ["Updated", "updated@example.com", 1, 2, 3, 25]})
  end

  it "matches NULL for a nil keyword value in WHERE clause" do
    update_query = Northwind.update.table(:users)
      .set(age: 1)
      .where(name: nil)
      .to_sql

    update_query.should eq({"UPDATE users SET age = ? WHERE users.name IS NULL", [1]})
  end

  it "matches NULL for a nil hash value in WHERE clause" do
    update_query = Northwind.update.table(:users)
      .set(age: 1)
      .where({:name => nil} of Symbol => DB::Any)
      .to_sql

    update_query.should eq({"UPDATE users SET age = ? WHERE users.name IS NULL", [1]})
  end

  it "matches NULL for == nil in a WHERE block" do
    update_query = Northwind.update.table(:users)
      .set(age: 1)
      .where { users.name == nil }
      .to_sql

    update_query.should eq({"UPDATE users SET age = ? WHERE users.name IS NULL", [1]})
  end

  it "binds a nil value in SET clause" do
    update_query = Northwind.update.table(:users)
      .set(name: nil)
      .where(id: 1)
      .to_sql

    update_query.should eq({"UPDATE users SET name = ? WHERE users.id = ?", [nil, 1]})
  end

  it "raises ArgumentError for a table the schema does not know" do
    expect_raises(ArgumentError, "Table nope not found") { Northwind.update.table(:nope) }
  end
end

LOCKED_UPDATE_DB = CQL::Schema.define(:locked_update_spec, adapter: CQL::Adapter::SQLite, uri: "sqlite3::memory:") do
  table :documents do
    primary :id, Int32, auto_increment: true
    text :title
    integer :version
  end
end

describe "CQL::Update#with_optimistic_lock" do
  locked_update = -> { LOCKED_UPDATE_DB.update.table(:documents).set(title: "B").where(id: 1).with_optimistic_lock(version: 3, column: :version) }
  locked_sql = {"UPDATE documents SET title = ?, version = ? WHERE (documents.id = ?) AND (documents.version = ?)", ["B", 4, 1, 3]}

  it "shows the version check and the next version in to_sql, leaving the builder and the column as they were" do
    update = locked_update.call
    update.to_sql.should eq locked_sql
    update.to_sql.should eq locked_sql
    LOCKED_UPDATE_DB.documents.columns[:version].version_number?.should be_false
  end

  it "numbers the version's parameters after the others on PostgreSQL" do
    sql = locked_update.call.to_sql(Expression::Generator.new(CQL::Adapter::Postgres))
    sql.should eq({"UPDATE documents SET title = $1, version = $2 WHERE (documents.id = $3) AND (documents.version = $4)", ["B", 4, 1, 3]})
  end

  it "checks the version column without column:, and refuses a column the table lacks" do
    update = LOCKED_UPDATE_DB.update.table(:documents).set(title: "B").with_optimistic_lock(version: 3)
    update.to_sql.should eq({"UPDATE documents SET title = ?, version = ? WHERE documents.version = ?", ["B", 4, 3]})
    expect_raises(CQL::Error, "Specified version column 'nope' not found in table 'documents'") do
      update.with_optimistic_lock(version: 3, column: :nope).to_sql
    end
  end

  it "raises on a second commit of the same builder, without assigning the version twice" do
    LOCKED_UPDATE_DB.build
    LOCKED_UPDATE_DB.exec("INSERT INTO documents (id, title, version) VALUES (1, 'A', 3)")
    update = locked_update.call
    update.commit.rows_affected.should eq 1
    expect_raises(CQL::OptimisticLockError) { update.commit }
    update.to_sql.should eq locked_sql
    LOCKED_UPDATE_DB.query.from(:documents).select(:version).where(id: 1).first!(as: Int32).should eq 4
    LOCKED_UPDATE_DB.documents.columns[:version].version_number?.should be_false
  end
end
