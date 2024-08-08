require "./spec_helper"

describe Cql::Update do
  it "creates Update query" do
    update_query = u.update(:users)
      .set(name: "John", email: "john@example.com")
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      UPDATE users SET name = ?, email = ?
      SQL

    update_query.should eq({output, ["John", "john@example.com"]})
  end

  it "create update where query" do
    update_query = u.update(:users)
      .set(name: "John", email: "john@example.com")
      .where { users.id == 1 }
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      UPDATE users SET name = ?, email = ?
      WHERE (users.id = ?)
      SQL
    update_query.should eq({output, ["John", "john@example.com", 1]})
  end
end
