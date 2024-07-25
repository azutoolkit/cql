require "./spec_helper"

describe Sql::Delete do
  it "Delete specific rows that meet a certain condition." do
    delete_query = d.from(:users)
      .where { users.id == 1_i64 }
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      DELETE FROM users WHERE (users.id = ?)
      SQL

    delete_query.should eq({output, [1]})
  end

  it "Delete rows based on the result of a subquery." do
    sub_query = q.from(:users)
      .select(:id)
      .where { users.id == 1_i64 }

    delete_query = d.from(:users)
      .where { exists?(sub_query) }
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
    DELETE FROM users WHERE (EXISTS (SELECT users.id FROM users WHERE (users.id = ?)))
    SQL

    delete_query.should eq({output, [1]})
  end

  it "Delete rows from one table based on a condition in another table using a join." do
    delete_query = d.from(:users)
      .using(:address)
      .where { (users.id == address.user_id) & (address.city == "Berlin") }
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
    DELETE FROM users USING address WHERE (users.id = address.user_id AND address.city = ?)
    SQL

    delete_query.should eq({output, ["Berlin"]})
  end

  it "Delete rows and return the deleted rows." do
    delete_query = d.from(:users)
      .where { users.id == 1_i64 }
      .back(:id)
      .to_sql

    output = <<-SQL.gsub(/\n/, " ").strip
      DELETE FROM users WHERE (users.id = ?) RETURNING (users.id)
      SQL

    delete_query.should eq({output, [1]})
  end
end
