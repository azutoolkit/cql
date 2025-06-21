require "../spec_helper"

describe CQL::Delete do
  it "creates Delete query" do
    delete_query = Northwind.delete
      .from(:users)
      .where(id: 1)
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      DELETE FROM users WHERE users.id = ?
      SQL

    delete_query.should eq({output, [1]})
  end

  it "handles array values in WHERE clause" do
    delete_query = Northwind.delete
      .from(:users)
      .where(id: [1, 2, 3])
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      DELETE FROM users WHERE users.id IN (?, ?, ?)
      SQL

    delete_query.should eq({output, [1, 2, 3]})
  end

  it "handles multiple array conditions in WHERE clause" do
    delete_query = Northwind.delete
      .from(:users)
      .where(id: [1, 2, 3], name: ["Alice", "Bob"])
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      DELETE FROM users WHERE (users.id IN (?, ?, ?)) AND (users.name IN (?, ?))
      SQL

    delete_query.should eq({output, [1, 2, 3, "Alice", "Bob"]})
  end

  it "handles array values with other conditions in WHERE clause" do
    delete_query = Northwind.delete
      .from(:users)
      .where(id: [1, 2, 3], age: 25)
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      DELETE FROM users WHERE (users.id IN (?, ?, ?)) AND (users.age = ?)
      SQL

    delete_query.should eq({output, [1, 2, 3, 25]})
  end

  it "handles empty array in WHERE clause" do
    delete_query = Northwind.delete
      .from(:users)
      .where(id: [] of Int32)
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      DELETE FROM users WHERE users.id IN ()
      SQL

    delete_query.should eq({output, [] of DB::Any})
  end

  it "handles single element array in WHERE clause" do
    delete_query = Northwind.delete
      .from(:users)
      .where(id: [1])
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      DELETE FROM users WHERE users.id IN (?)
      SQL

    delete_query.should eq({output, [1]})
  end
end
