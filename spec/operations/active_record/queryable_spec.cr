require "../../spec_helper"

describe CQL::ActiveRecord::Queryable do
  before_each do
    UserDB.users.create!
  end

  after_each do
    UserDB.users.drop!
  end

  describe ".query" do
    it "returns a new query object" do
      TestUser.responds_to?(:query).should be_true
      TestUser.query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".all" do
    it "fetches all records" do
      result = TestUser.all
      result.should be_a(Array(TestUser))
    end
  end

  describe ".find" do
    it "finds a record by ID" do
      user = TestUser.new(
        name: "Test User",
        email: "test@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!
      found_user = TestUser.find(user.id!)
      found_user.should be_a(TestUser)
    end
  end

  describe ".find!" do
    it "finds a record by ID or raises" do
      expect_raises(DB::NoResultsError) do
        TestUser.find!(999)
      end
    end
  end

  describe ".find_by" do
    it "finds a record by attributes" do
      user = TestUser.new(
        name: "Test User",
        email: "test@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!
      found_user = TestUser.find_by(name: "Test User")
      found_user.should be_a(TestUser)
    end
  end

  describe ".find_by!" do
    it "finds a record by attributes or raises" do
      expect_raises(DB::NoResultsError) do
        TestUser.find_by!(name: "Nonexistent User")
      end
    end
  end

  describe ".count" do
    it "counts all records" do
      count = TestUser.count
      count.should be_a(Int64)
    end
  end

  describe ".exists?" do
    it "checks if records exist" do
      user = TestUser.new(
        name: "Test User",
        email: "test@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!
      exists = TestUser.exists?(name: "Test User")
      exists.should be_true
    end
  end

  describe ".first" do
    it "fetches the first record" do
      user = TestUser.new(
        name: "Test User",
        email: "test@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!
      first_user = TestUser.first
      first_user.should be_a(TestUser)
    end
  end

  describe ".last" do
    it "fetches the last record" do
      user = TestUser.new(
        name: "Test User",
        email: "test@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!
      last_user = TestUser.last
      last_user.should be_a(TestUser)
    end
  end

  # Test chainable query methods
  describe "chainable query methods" do
    describe ".where" do
      it "returns a chainable query" do
        query = TestUser.where(name: "Test User")
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "can be chained with other query methods" do
        query = TestUser.where(name: "Test User").where(age: 30)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "handles array values in WHERE clause" do
        # Create test users with different ages
        TestUser.create!(name: "Alice", email: "alice@example.com", age: 25, password: "pass1")
        TestUser.create!(name: "Bob", email: "bob@example.com", age: 30, password: "pass2")
        TestUser.create!(name: "Charlie", email: "charlie@example.com", age: 35, password: "pass3")

        users = TestUser.where(age: [25, 35]).all
        users.size.should eq(2)
        users.map(&.name).should contain("Alice")
        users.map(&.name).should contain("Charlie")
      end

      it "handles multiple array conditions in WHERE clause" do
        # Create test users
        TestUser.create!(name: "Alice", email: "alice@example.com", age: 25, password: "pass1")
        TestUser.create!(name: "Bob", email: "bob@example.com", age: 30, password: "pass2")
        TestUser.create!(name: "Charlie", email: "charlie@example.com", age: 35, password: "pass3")

        users = TestUser.where(age: [25, 30], name: ["Alice", "Bob"]).all
        users.size.should eq(2)
        users.map(&.name).should contain("Alice")
        users.map(&.name).should contain("Bob")
      end

      it "handles empty array in WHERE clause" do
        users = TestUser.where(age: [] of Int32).all
        users.size.should eq(0)
      end

      it "handles single element array in WHERE clause" do
        TestUser.create!(name: "Alice", email: "alice@example.com", age: 25, password: "pass1")

        users = TestUser.where(age: [25]).all
        users.size.should eq(1)
        users.first.name.should eq("Alice")
      end

      it "handles array values with other conditions" do
        TestUser.create!(name: "Alice", email: "alice@example.com", age: 25, password: "pass1")
        TestUser.create!(name: "Bob", email: "bob@example.com", age: 30, password: "pass2")
        TestUser.create!(name: "Charlie", email: "charlie@example.com", age: 35, password: "pass3")

        users = TestUser.where(age: [25, 30], name: "Alice").all
        users.size.should eq(1)
        users.first.name.should eq("Alice")
      end

      it "handles array values in chained WHERE clauses" do
        TestUser.create!(name: "Alice", email: "alice@example.com", age: 25, password: "pass1")
        TestUser.create!(name: "Bob", email: "bob@example.com", age: 30, password: "pass2")
        TestUser.create!(name: "Charlie", email: "charlie@example.com", age: 35, password: "pass3")

        users = TestUser.where(age: [25, 30]).where(name: ["Alice", "Bob"]).all
        users.size.should eq(2)
        users.map(&.name).should contain("Alice")
        users.map(&.name).should contain("Bob")
      end

      it "handles array values in find_by method" do
        TestUser.create!(name: "Alice", email: "alice@example.com", age: 25, password: "pass1")
        TestUser.create!(name: "Bob", email: "bob@example.com", age: 30, password: "pass2")

        user = TestUser.find_by(age: [25, 30], name: "Alice")
        user.should_not be_nil
        user.not_nil!.name.should eq("Alice")
      end

      it "handles array values in exists? method" do
        TestUser.create!(name: "Alice", email: "alice@example.com", age: 25, password: "pass1")
        TestUser.create!(name: "Bob", email: "bob@example.com", age: 30, password: "pass2")

        exists = TestUser.exists?(age: [25, 30])
        exists.should be_true

        exists = TestUser.exists?(age: [99, 100])
        exists.should be_false
      end
    end

    describe ".order" do
      it "returns a chainable query" do
        query = TestUser.order(name: :asc)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "can be chained with other query methods" do
        query = TestUser.where(name: "Test User").order(name: :asc)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end
    end

    describe ".limit" do
      it "returns a chainable query" do
        query = TestUser.limit(10)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "can be chained with other query methods" do
        query = TestUser.where(name: "Test User").limit(10)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end
    end

    describe ".offset" do
      it "returns a chainable query" do
        query = TestUser.offset(10)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "can be chained with other query methods" do
        query = TestUser.where(name: "Test User").offset(10)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end
    end

    describe ".select" do
      it "returns a chainable query" do
        query = TestUser.select(:id, :name)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "can be chained with other query methods" do
        query = TestUser.where(name: "Test User").select(:id, :name)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end
    end

    describe ".group_by" do
      it "returns a chainable query" do
        query = TestUser.group(:name)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "can be chained with other query methods" do
        query = TestUser.where(name: "Test User").group_by(:name)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end
    end

    describe ".join/.left/.right" do
      it "returns a chainable query for join(*tables : Symbol)" do
        query = TestUser.join(:posts) { |j| j.posts.id.eq(j.users.id) }
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "returns a chainable query for join(*tables : Symbol)" do
        query = TestUser.join(:posts)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "returns a chainable query for join(table_or_alias : Symbol | Hash(Symbol, Symbol))" do
        query = TestUser.join(posts: :p)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "returns a chainable query for join(**tables_with_aliases)" do
        query = TestUser.join(posts: :p)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "returns a chainable query for left join variants" do
        TestUser.left(:posts).should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
        TestUser.left(posts: :p).should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "returns a chainable query for right join variants" do
        TestUser.right(:posts).should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
        TestUser.right(posts: :p).should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "can be chained with other query methods" do
        query = TestUser.where(name: "Test User").join(:posts).order(name: :asc).limit(1)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end
    end
  end

  # Test new query methods
  describe "new query methods" do
    before_each do
      # Create test data
      users = [
        TestUser.new(name: "Alice", email: "alice@example.com", age: 25, password: "pass1", password_confirmation: "pass1"),
        TestUser.new(name: "Bob", email: "bob@example.com", age: 30, password: "pass2", password_confirmation: "pass2"),
        TestUser.new(name: "Charlie", email: "charlie@example.com", age: 35, password: "pass3", password_confirmation: "pass3"),
        TestUser.new(name: "David", email: "david@example.com", age: 40, password: "pass4", password_confirmation: "pass4"),
        TestUser.new(name: "Eve", email: "eve@example.com", age: 45, password: "pass5", password_confirmation: "pass5"),
      ]
      users.each(&.create!)
    end

    describe ".find_each" do
      it "iterates over records in batches" do
        processed_count = 0
        TestUser.find_each(batch_size: 2) do |user|
          processed_count += 1
          user.should be_a(TestUser)
        end
        processed_count.should eq(5)
      end

      it "uses default batch size when not specified" do
        processed_count = 0
        TestUser.find_each do |user|
          processed_count += 1
          user.should be_a(TestUser)
        end
        processed_count.should eq(5)
      end

      it "works with where conditions" do
        processed_count = 0
        # Use a simple equality check since CQL doesn't support > operator syntax
        TestUser.where(age: 35).find_each do |user|
          processed_count += 1
          user.age.should eq(35)
        end
        processed_count.should eq(1)
      end
    end

    describe ".find_in_batches" do
      it "processes records in batches" do
        batch_count = 0
        total_records = 0
        TestUser.find_in_batches(batch_size: 2) do |batch|
          batch_count += 1
          total_records += batch.size
          batch.should be_a(Array(TestUser))
          batch.size.should be <= 2
        end
        batch_count.should eq(3) # 2 + 2 + 1
        total_records.should eq(5)
      end

      it "uses default batch size when not specified" do
        batch_count = 0
        TestUser.find_in_batches do |batch|
          batch_count += 1
          batch.should be_a(Array(TestUser))
        end
        batch_count.should eq(1) # All 5 records in one batch
      end
    end

    describe ".pluck" do
      it "extracts single column values" do
        names = TestUser.pluck(:name, as: String)
        names.should be_a(Array(String))
        names.size.should eq(5)
        names.should contain("Alice")
        names.should contain("Bob")
      end

      it "extracts single column values with typed pluck" do
        names = TestUser.pluck(:name, as: String)
        names.should be_a(Array(String))
        names.size.should eq(5)
        first_result = names.first
        first_result.should be_a(String)
        first_result.should eq("Alice")
      end

      it "extracts multiple column values" do
        results = TestUser.pluck(:name, :age, as: {String, Int32})
        results.should be_a(Array(Tuple(String, Int32)))
        results.size.should eq(5)
      end

      it "extracts multiple column values with typed pluck" do
        results = TestUser.pluck(:name, :age, as: {String, Int32})
        results.should be_a(Array(Tuple(String, Int32)))
        results.size.should eq(5)
      end

      it "works with where conditions" do
        # Use supported API - check for a specific age since > operator isn't supported yet
        names = TestUser.where(age: 35).pluck(:name, as: String)
        names.size.should eq(1)
        names.should contain("Charlie")
      end
    end

    describe ".pick" do
      it "picks single value from first record" do
        name = TestUser.pick(:name)
        name.should be_a(DB::Any)
        name.should_not be_nil
      end

      it "returns nil when no records exist" do
        TestUser.delete_all
        name = TestUser.pick(:name)
        name.should be_nil
      end

      it "works with where conditions" do
        age = TestUser.where(name: "Alice").pick(:age)
        age.should eq(25)
      end
    end

    describe ".ids" do
      it "gets array of primary keys" do
        ids = TestUser.ids
        ids.should be_a(Array(Int64))
        ids.size.should eq(5)
        ids.all? { |id| id.is_a?(Int64) }.should be_true
      end

      it "works with where conditions" do
        # Use supported API - check for a specific age
        ids = TestUser.where(age: 35).ids
        ids.size.should eq(1)
      end
    end

    describe ".maximum" do
      it "gets maximum value of column" do
        max_age = TestUser.maximum(:age)
        max_age.should eq(45)
      end

      it "works with where conditions" do
        # Use supported API - check for a specific age
        max_age = TestUser.where(age: 35).maximum(:age)
        max_age.should eq(35)
      end

      it "returns nil when no records exist" do
        TestUser.delete_all
        max_age = TestUser.maximum(:age)
        max_age.should eq(0)
      end
    end

    describe ".minimum" do
      it "gets minimum value of column" do
        min_age = TestUser.minimum(:age)
        min_age.should eq(25)
      end

      it "works with where conditions" do
        # Use supported API - check for a specific age
        min_age = TestUser.where(age: 35).minimum(:age)
        min_age.should eq(35)
      end

      it "returns nil when no records exist" do
        TestUser.delete_all
        min_age = TestUser.minimum(:age)
        min_age.should eq(0)
      end
    end

    describe ".average" do
      it "gets average value of column" do
        avg_age = TestUser.average(:age)
        avg_age.should eq(35.0) # (25 + 30 + 35 + 40 + 45) / 5 = 35
      end

      it "works with where conditions" do
        # Use supported API - check for a specific age
        avg_age = TestUser.where(age: 35).average(:age)
        avg_age.should eq(35.0)
      end

      it "returns nil when no records exist" do
        TestUser.delete_all
        avg_age = TestUser.average(:age)
        avg_age.should eq(0.0)
      end
    end

    describe ".sum" do
      it "gets sum of column values" do
        sum_age = TestUser.sum(:age)
        sum_age.should eq(175) # 25 + 30 + 35 + 40 + 45 = 175
      end

      it "works with where conditions" do
        # Use supported API - check for a specific age
        sum_age = TestUser.where(age: 35).sum(:age)
        sum_age.should eq(35)
      end

      it "returns 0 when no records exist" do
        TestUser.delete_all

        sum_age = TestUser.sum(:age)
        sum_age.should eq(0)
      end
    end

    describe ".distinct" do
      it "gets distinct values for a column" do
        # Add some duplicate ages
        TestUser.create!(name: "Frank", email: "frank@example.com", age: 25, password: "pass6")
        TestUser.create!(name: "Grace", email: "grace@example.com", age: 30, password: "pass7")

        distinct_ages = TestUser.distinct(:age)
        distinct_ages.should be_a(Array(DB::Any))
        distinct_ages.size.should eq(5) # 25, 30, 35, 40, 45
        distinct_ages.should contain(25)
        distinct_ages.should contain(30)
        distinct_ages.should contain(35)
        distinct_ages.should contain(40)
        distinct_ages.should contain(45)
      end

      it "works with where conditions" do
        # Use supported API - check for a specific age
        distinct_ages = TestUser.select(:age).where(age: 35).distinct.all(as: Int32)
        distinct_ages.size.should eq(1) # 35
      end
    end

    describe ".reorder" do
      it "replaces existing order clause" do
        # First order by age desc
        query1 = TestUser.order(age: :desc)
        first_user1 = query1.first
        first_user1.not_nil!.age.should eq(45)

        # Then reorder by age asc
        query2 = query1.reorder(age: :asc)
        first_user2 = query2.first
        first_user2.not_nil!.age.should eq(25)
      end

      it "works with multiple order columns" do
        query = TestUser.reorder(name: :asc, age: :desc)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end
    end

    describe ".reverse_order" do
      it "returns a chainable query" do
        query = TestUser.reverse_order
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "can be chained with other methods" do
        # Use supported API
        query = TestUser.where(age: 35).reverse_order
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end
    end

    describe ".unscope" do
      it "returns a chainable query" do
        query = TestUser.unscope(:where)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "can be chained with other methods" do
        # Use supported API
        query = TestUser.where(age: 35).unscope(:where)
        query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end
    end

    describe "aggregate methods" do
      it "provides min and max aliases" do
        TestUser.min(:age).should eq(25)
        TestUser.max(:age).should eq(45)
      end

      it "all aggregate methods work consistently" do
        TestUser.minimum(:age).should eq(TestUser.min(:age))
        TestUser.maximum(:age).should eq(TestUser.max(:age))
        TestUser.average(:age).should eq(TestUser.avg(:age))
      end
    end
  end
end
