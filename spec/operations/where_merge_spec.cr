require "../spec_helper"

# Chained where calls must AND together. Previously Update/Delete replaced the
# earlier condition, so `delete.where(a: 1).where(b: 2)` matched far more rows.
describe "Chained WHERE on Update and Delete" do
  it "ANDs chained keyword where calls on DELETE" do
    sql, params = Northwind.delete.from(:users).where(name: "Ada").where(email: "ada@example.com").to_sql

    sql.should eq("DELETE FROM users WHERE (users.name = ?) AND (users.email = ?)")
    params.should eq(["Ada", "ada@example.com"] of DB::Any)
  end

  it "ANDs a block where after a keyword where on DELETE" do
    sql, params = Northwind.delete.from(:users).where(name: "Ada").where { users.age > 30 }.to_sql

    sql.should contain("users.name = ?")
    sql.should contain("users.age > ?")
    sql.should contain(" AND ")
    params.should eq(["Ada", 30] of DB::Any)
  end

  it "ANDs chained where calls on UPDATE" do
    sql, params = Northwind.update.table(:users).set(age: 31).where(name: "Ada").where(email: "ada@example.com").to_sql

    sql.should contain("WHERE (users.name = ?) AND (users.email = ?)")
    params.should eq([31, "Ada", "ada@example.com"] of DB::Any)
  end

  it "ANDs hash where calls on UPDATE and DELETE" do
    _, update_params = Northwind.update.table(:users).set(age: 31)
      .where({:name => "Ada"} of Symbol => DB::Any)
      .where({:email => "ada@example.com"} of Symbol => DB::Any).to_sql
    _, delete_params = Northwind.delete.from(:users)
      .where({:name => "Ada"} of Symbol => DB::Any)
      .where({:email => "ada@example.com"} of Symbol => DB::Any).to_sql

    update_params.should eq([31, "Ada", "ada@example.com"] of DB::Any)
    delete_params.should eq(["Ada", "ada@example.com"] of DB::Any)
  end
end
