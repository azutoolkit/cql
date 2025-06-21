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
end
