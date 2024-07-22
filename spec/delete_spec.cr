require "./spec_helper"

describe Sql::Delete do
  it "Delete specific rows that meet a certain condition." do
    delete_query = d.from(:users)
      .where { users.id == 1 }
      .to_sql

    delete_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      DELETE FROM users WHERE (users.id = 1)
      SQL
    )
  end

  it "Delete rows based on the result of a subquery." do
    sub_query = q.from(:users)
      .select(:id)
      .where { users.id == 1 }

    delete_query = d.from(:users)
      .where { exists?(sub_query) }
      .to_sql

    delete_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      DELETE FROM users WHERE (EXISTS (SELECT users.id FROM users WHERE (users.id = 1)))
      SQL
    )
  end

  it "Delete rows from one table based on a condition in another table using a join." do
    delete_query = d.from(:users)
      .using(:address)
      .where { (users.id == address.user_id) & (address.city == "'Berlin'") }
      .to_sql

    delete_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      DELETE FROM users USING address WHERE (users.id = address.user_id AND address.city = 'Berlin')
      SQL
    )
  end

  it "Delete rows and return the deleted rows." do
    delete_query = d.from(:users)
      .where { users.id == 1 }
      .back(:id)
      .to_sql

    delete_query.should eq(
      <<-SQL.gsub(/\n/, " ").strip
      DELETE FROM users WHERE (users.id = 1) RETURNING (users.id)
      SQL
    )
  end
end
