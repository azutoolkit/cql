require "../../spec_helper"

describe "Range Support in Where Queries" do
  before_each do
    UserDB.users.create!
  end

  after_each do
    UserDB.users.drop!
  end

  context "with test data" do
    before_each do
      # Create test data for each test
      TestUser.create!(
        name: "Alice",
        email: "alice@example.com",
        age: 25,
        password: "password123"
      )
      TestUser.create!(
        name: "Bob",
        email: "bob@example.com",
        age: 30,
        password: "password456"
      )
      TestUser.create!(
        name: "Charlie",
        email: "charlie@example.com",
        age: 35,
        password: "password789"
      )
      TestUser.create!(
        name: "Diana",
        email: "diana@example.com",
        age: 40,
        password: "password101"
      )
    end

    describe "Integer Range Support" do
      it "filters with Int32 range" do
        users = TestUser.query.where(age: 25..35).all
        users.size.should eq(3)
        users.map(&.name).should contain("Alice")
        users.map(&.name).should contain("Bob")
        users.map(&.name).should contain("Charlie")
      end

      it "filters with Int64 range" do
        users = TestUser.query.where(age: 25_i64..35_i64).all
        users.size.should eq(3)
        users.map(&.name).should contain("Alice")
        users.map(&.name).should contain("Bob")
        users.map(&.name).should contain("Charlie")
      end

      it "handles empty range results" do
        users = TestUser.query.where(age: 50..60).all
        users.size.should eq(0)
      end

      it "handles single value range" do
        users = TestUser.query.where(age: 30..30).all
        users.size.should eq(1)
        users.first.name.should eq("Bob")
      end

      it "handles range with one match" do
        users = TestUser.query.where(age: 28..32).all
        users.size.should eq(1)
        users.first.name.should eq("Bob")
      end
    end

    describe "Complex Range Queries" do
      it "combines range with other conditions" do
        users = TestUser.query
          .where(age: 25..35)
          .where_like(:name, "%A%")
          .all
        users.size.should eq(2)
        users.map(&.name).should contain("Alice")
        users.map(&.name).should contain("Charlie")
      end

      it "combines range with hash conditions" do
        users = TestUser.query
          .where(age: 25..35, name: "Bob")
          .all
        users.size.should eq(1)
        users.first.name.should eq("Bob")
      end

      it "combines range with array conditions" do
        users = TestUser.query
          .where(age: 25..35)
          .where(name: ["Alice", "Bob"])
          .all
        users.size.should eq(2)
        users.map(&.name).should contain("Alice")
        users.map(&.name).should contain("Bob")
      end
    end

    describe "Range Edge Cases" do
      it "handles range with no data" do
        users = TestUser.query.where(age: 100..200).all
        users.size.should eq(0)
      end

      it "handles range where all data matches" do
        users = TestUser.query.where(age: 20..50).all
        users.size.should eq(4)
      end

      it "handles range with exact boundary values" do
        users = TestUser.query.where(age: 25..40).all
        users.size.should eq(4)
      end

      it "handles range with single boundary match" do
        users = TestUser.query.where(age: 25..26).all
        users.size.should eq(1)
        users.first.name.should eq("Alice")
      end
    end

    describe "Range with Ordering" do
      it "combines range with order by" do
        users = TestUser.query
          .where(age: 25..35)
          .order(:name)
          .all
        users.size.should eq(3)
        users.map(&.name).should eq(["Alice", "Bob", "Charlie"])
      end

      it "combines range with limit" do
        users = TestUser.query
          .where(age: 25..40)
          .limit(2)
          .all
        users.size.should eq(2)
      end

      it "combines range with offset" do
        users = TestUser.query
          .where(age: 25..40)
          .order(:age)
          .offset(1)
          .limit(2)
          .all
        users.size.should eq(2)
        users.first.name.should eq("Bob")    # age 30
        users.last.name.should eq("Charlie") # age 35
      end
    end

    describe "Range with Aggregates" do
      it "counts records in range" do
        count = TestUser.query.where(age: 25..35).count
        count.should eq(3)
      end

      it "finds maximum value in range" do
        max_age = TestUser.query.where(age: 25..35).max(:age)
        max_age.should eq(35)
      end

      it "finds minimum value in range" do
        min_age = TestUser.query.where(age: 25..35).min(:age)
        min_age.should eq(25)
      end

      it "calculates average in range" do
        avg_age = TestUser.query.where(age: 25..35).avg(:age)
        avg_age.should eq(30.0)
      end
    end

    describe "Range SQL Generation" do
      it "generates correct SQL for range query" do
        query = TestUser.query.where(age: 25..35)
        sql, params = query.query.to_sql
        sql.should contain("BETWEEN")
        params.size.should eq(2)
        params[0].should eq(25)
        params[1].should eq(35)
      end
    end

    describe "Range Type Safety" do
      it "handles different integer types" do
        # Test that Int32 and Int64 ranges work correctly
        users_int32 = TestUser.query.where(age: 25..35).all
        users_int64 = TestUser.query.where(age: 25_i64..35_i64).all
        users_int32.size.should eq(users_int64.size)
        users_int32.map(&.name).should eq(users_int64.map(&.name))
      end
    end
  end
end
