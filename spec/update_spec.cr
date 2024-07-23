require "./spec_helper"

describe Sql::Update do
  it "creates Update query" do
    update_query = u.update(:users)
      .set(name: "'John'", email: "'john@example.com'")
      .to_sql

    update_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      UPDATE users SET users.name = 'John', users.email = 'john@example.com'
      SQL
    )
  end

  it "create update where query" do
    update_query = u.update(:users)
      .set(name: "'John'", email: "'john@example.com'")
      .where { users.id == 1_i64 }
      .to_sql

    update_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      UPDATE users SET users.name = 'John', users.email = 'john@example.com'
      WHERE (users.id = 1)
      SQL
    )
  end
end
