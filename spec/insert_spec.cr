require "./spec_helper"

describe Sql::Insert do
  it "creates Insert Into query" do
    insert_query = i.into(:users).values(name: "'John'", email: "'john@example.com'").to_sql

    insert_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      INSERT INTO users (name, email) VALUES ('John', 'john@example.com')
      SQL
    )
  end

  it "creates Insert Into query with multiple rows" do
    insert_query = i.into(:users)
      .values(name: "'John'", email: "'john@example.com'")
      .values(name: "'Jane'", email: "'jane@example.com'")
      .to_sql

    insert_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      INSERT INTO users (name, email)
      VALUES ('John', 'john@example.com'), ('Jane', 'jane@example.com')
      SQL
    )
  end

  it "creates Insert Into query with Array(Hash(Symbol, DB::Any))" do
    insert_query = i.into(:users)
      .values(
        [{:name => "'John'", :email => "'john@doe.com'"},
         {:name => "'Jane'", :email => "'jane@doe.com'"}])
      .to_sql

    insert_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      INSERT INTO users (name, email)
      VALUES ('John', 'john@doe.com'), ('Jane', 'jane@doe.com')
      SQL
    )
  end

  it "creates Insert Into query with returning clause" do
    insert_query = i.into(:users)
      .values(name: "'John'", email: "'jane@example.com'")
      .back(:id)
      .to_sql

    insert_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      INSERT INTO users (name, email) VALUES ('John', 'jane@example.com') RETURNING (users.id)
      SQL
    )
  end

  it "creates Insert Into with select query" do
    select_query = q.from(:users)
      .select(:name, :email)
      .where { users.id == 1_i64 }

    insert_query = i.into(:users)
      .query(select_query)
      .to_sql

    insert_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      INSERT INTO users (name, email)
      SELECT users.name, users.email
      FROM users WHERE (users.id = 1)
      SQL
    )
  end
end
