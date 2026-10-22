require "../spec_helper"

describe "Set operations" do
  pg = -> { Expression::Generator.new(CQL::Adapter::Postgres) }
  customers = -> { Northwind.query.from(:customers).select(:name) }
  users = -> { Northwind.query.from(:users).select(:name) }

  it "UNION" do
    sql, params = customers.call.union(users.call).to_sql

    sql.should eq("SELECT customers.name FROM customers UNION SELECT users.name FROM users")
    params.should be_empty
  end

  it "UNION ALL, INTERSECT and EXCEPT" do
    customers.call.union_all(users.call).to_sql[0].should contain(" UNION ALL ")
    customers.call.intersect(users.call).to_sql[0].should contain(" INTERSECT ")
    customers.call.except(users.call).to_sql[0].should contain(" EXCEPT ")
  end

  it "binds parameters from both sides in order" do
    sql, params = customers.call.where(city: "Tulum").union(users.call.where(email: "a@example.com")).to_sql

    params.should eq(["Tulum", "a@example.com"] of DB::Any)
    sql.should contain("customers.city = ? UNION SELECT users.name FROM users WHERE users.email = ?")
  end

  it "keeps $n numbering across operands on PostgreSQL" do
    sql, params = customers.call.where(city: "Tulum").union(users.call.where(email: "a@example.com")).to_sql(pg.call)

    params.should eq(["Tulum", "a@example.com"] of DB::Any)
    sql.should contain("customers.city = $1 UNION")
    sql.should end_with("users.email = $2")
  end

  it "chains left to right (grouping the left chain as a derived table on SQLite)" do
    sql, _ = customers.call.union(users.call).except(users.call).to_sql
    sql.should start_with("SELECT * FROM (SELECT customers.name FROM customers UNION SELECT users.name FROM users) EXCEPT SELECT users.name FROM users")
  end

  it "groups a nested compound operand: parentheses, or a derived table on SQLite" do
    chain = customers.call.union(users.call).intersect(users.call)

    chain.to_sql(pg.call)[0].should start_with("(SELECT customers.name FROM customers UNION SELECT users.name FROM users) INTERSECT ")
    chain.to_sql[0].should start_with("SELECT * FROM (SELECT customers.name FROM customers UNION SELECT users.name FROM users) INTERSECT ")
  end

  it "is executable" do
    UserDB.users.create!
    UserDB.profile_owners.create!
    begin
      UserDB.insert.into(:users).values(name: "ada", email: "a@x.io", age: 1, password: "pw").commit
      UserDB.insert.into(:profile_owners).values(name: "ada", email: "o@x.io", age: 1, password: "pw", password_confirmation: "pw").commit
      UserDB.insert.into(:profile_owners).values(name: "grace", email: "g@x.io", age: 1, password: "pw", password_confirmation: "pw").commit

      user_names = UserDB.query.from(:users).select(:name)
      owner_names = UserDB.query.from(:profile_owners).select(:name)

      user_names.union(owner_names).all(as: String).sort.should eq(["ada", "grace"])
      user_names.union_all(owner_names).all(as: String).sort.should eq(["ada", "ada", "grace"])
      owner_names.except(user_names).all(as: String).should eq(["grace"])
      owner_names.intersect(user_names).all(as: String).should eq(["ada"])
    ensure
      UserDB.profile_owners.drop!
      UserDB.users.drop!
    end
  end

  describe "operands that need grouping" do
    ordered = -> { customers.call.order(name: :asc).limit(1) }

    it "wraps an operand with ORDER BY / LIMIT so the clauses stay on that operand (PostgreSQL)" do
      sql, params = ordered.call.union(users.call).to_sql(pg.call)
      sql.should eq("(SELECT customers.name FROM customers ORDER BY customers.name ASC LIMIT $1) UNION SELECT users.name FROM users")
      params.should eq([1] of DB::Any)

      right, _ = users.call.union(customers.call.limit(2)).to_sql(pg.call)
      right.should end_with("UNION (SELECT customers.name FROM customers LIMIT $1)")
    end

    it "wraps such operands as derived tables on SQLite, which has no parentheses" do
      sql, _ = users.call.union(customers.call.limit(2)).to_sql
      sql.should end_with("UNION SELECT * FROM (SELECT customers.name FROM customers LIMIT ?)")
    end

    it "keeps a right-nested compound's meaning on SQLite" do
      sql, _ = customers.call.except(users.call.union(customers.call)).to_sql
      sql.should contain("EXCEPT SELECT * FROM (SELECT users.name FROM users UNION SELECT customers.name FROM customers)")
    end

    it "executes the bounded operands correctly" do
      UserDB.users.create!
      UserDB.profile_owners.create!
      begin
        %w[ada grace linus].each_with_index do |name, i|
          UserDB.insert.into(:users).values(name: name, email: "#{name}@x.io", age: i, password: "pw").commit
        end
        UserDB.insert.into(:profile_owners).values(name: "zed", email: "z@x.io", age: 1, password: "pw", password_confirmation: "pw").commit
        names = UserDB.query.from(:users).select(:name)
        owners = UserDB.query.from(:profile_owners).select(:name)

        # LIMIT applies to the operand, not to the combined result
        names.union(owners.limit(1)).all(as: String).sort.should eq(%w[ada grace linus zed])
        names.order(name: :asc).limit(1).union(owners).all(as: String).sort.should eq(%w[ada zed])
        # right-nested: users - (owners UNION users) is empty
        names.except(owners.union(names)).all(as: String).should be_empty
      ensure
        UserDB.profile_owners.drop!
        UserDB.users.drop!
      end
    end

    it "renders MySQL set operations with parenthesized nested operands" do
      sql, _ = customers.call.union(users.call).intersect(users.call).to_sql(for: CQL::Adapter::MySql)
      sql.should start_with("(SELECT customers.name FROM customers UNION SELECT users.name FROM users) INTERSECT SELECT")
    end
  end
end
