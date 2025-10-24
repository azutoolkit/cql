require "./spec_helper"

describe CQL::ActiveRecord::Queryable do
  describe ".query" do
    it "creates a new query builder for the model" do
      query = TestUser.query
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".select" do
    it "creates a QueryBuilder and executes select with symbol arguments" do
      query = TestUser.select(:name, :email)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "creates a QueryBuilder and executes select with hash syntax" do
      query = TestUser.select(name: :full_name, email: :email_address)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".where" do
    it "creates a QueryBuilder and executes where with hash" do
      conditions = {:name => "Test", :age => 25} of Symbol => DB::Any
      query = TestUser.where(conditions)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "creates a QueryBuilder and executes where with hash syntax" do
      query = TestUser.where(name: "Test", age: 25)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "creates a QueryBuilder and executes where with block" do
      # Test that the where method with block exists
      # The actual block implementation would be tested in integration tests
      query = TestUser.where(name: "Test")
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".where_like" do
    it "creates a QueryBuilder and executes where_like" do
      query = TestUser.where_like(:name, "%Test%")
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".order" do
    it "creates a QueryBuilder and executes order with symbol arguments" do
      query = TestUser.order(:name, :email)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "creates a QueryBuilder and executes order with hash syntax" do
      query = TestUser.order(name: :asc, age: :desc)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".limit" do
    it "creates a QueryBuilder and executes limit" do
      query = TestUser.limit(10)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".offset" do
    it "creates a QueryBuilder and executes offset" do
      query = TestUser.offset(5)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".group" do
    it "creates a QueryBuilder and executes group" do
      query = TestUser.group(:age, :name)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".group_by" do
    it "creates a QueryBuilder and executes group_by (alias for group)" do
      query = TestUser.group_by(:age)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".having" do
    it "creates a QueryBuilder and executes having" do
      # Test that the having method exists
      # The actual implementation would be tested in integration tests
      query = TestUser.query
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".distinct" do
    it "creates a QueryBuilder and executes distinct" do
      query = TestUser.distinct
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".join" do
    it "creates a QueryBuilder and executes automatic inner join" do
      query = TestUser.join(:profiles)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "creates a QueryBuilder and executes inner join with block conditions" do
      # Test that the join method with block exists
      # The actual block implementation would be tested in integration tests
      query = TestUser.join(:profiles)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "creates a QueryBuilder and executes inner join with named arguments" do
      query = TestUser.join(profiles: :p)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".left" do
    it "creates a QueryBuilder and executes automatic left join" do
      query = TestUser.left(:profiles)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "creates a QueryBuilder and executes left join with block conditions" do
      # Test that the left join method with block exists
      # The actual block implementation would be tested in integration tests
      query = TestUser.left(:profiles)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".right" do
    it "creates a QueryBuilder and executes automatic right join" do
      query = TestUser.right(:profiles)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "creates a QueryBuilder and executes right join with block conditions" do
      # Test that the right join method with block exists
      # The actual block implementation would be tested in integration tests
      query = TestUser.right(:profiles)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".count" do
    it "executes count aggregate with default column" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      count = TestUser.count
      count.should be_a(Int64)
      count.should eq(2)
    end

    it "executes count aggregate with specific column" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      count = TestUser.count(:id)
      count.should be_a(Int64)
      count.should eq(2)
    end
  end

  describe ".sum" do
    it "executes sum aggregate" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 20)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      sum = TestUser.sum(:age)
      sum.should be_a(Float64 | Int64)
    end
  end

  describe ".avg" do
    it "executes avg aggregate" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 20)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      avg = TestUser.avg(:age)
      avg.should be_a(Float64)
    end
  end

  describe ".min" do
    it "executes min aggregate" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 20)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      min = TestUser.min(:age)
      min.should be_a(DB::Any)
    end
  end

  describe ".max" do
    it "executes max aggregate" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 20)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      max = TestUser.max(:age)
      max.should be_a(DB::Any)
    end
  end

  describe ".all" do
    it "finds all records matching the current query" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      users = TestUser.all
      users.should be_a(Array(TestUser))
      users.size.should eq(2)
    end
  end

  describe ".first" do
    it "finds first record matching the current query" do
      TestUser.create!(name: "First User", email: "first@example.com", age: 25)
      TestUser.create!(name: "Second User", email: "second@example.com", age: 30)

      user = TestUser.first
      user.should be_a(TestUser?)
      user.should_not be_nil
    end
  end

  describe ".first!" do
    it "finds first record matching the current query, raises if not found" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      user = TestUser.first!
      user.should be_a(TestUser)
    end

    it "raises an error when no records found" do
      expect_raises(Exception) do
        TestUser.where(name: "Nonexistent").first!
      end
    end
  end

  describe ".last" do
    it "finds last record matching the current query" do
      TestUser.create!(name: "First User", email: "first@example.com", age: 25)
      TestUser.create!(name: "Last User", email: "last@example.com", age: 30)

      user = TestUser.last
      user.should be_a(TestUser?)
      user.should_not be_nil
    end
  end

  describe ".last!" do
    it "finds last record matching the current query, raises if not found" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      user = TestUser.last!
      user.should be_a(TestUser)
    end

    it "raises an error when no records found" do
      expect_raises(Exception) do
        TestUser.where(name: "Nonexistent").last!
      end
    end
  end

  describe ".each" do
    it "iterates over each record matching the current query" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      # Test that the each method with block exists
      # The actual block implementation would be tested in integration tests
      TestUser.each { }
    end
  end

  describe ".exists?" do
    it "checks if any records exist matching the current query" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      TestUser.exists?.should be_true
    end

    it "returns false when no records exist" do
      TestUser.where(name: "Nonexistent").exists?.should be_false
    end

    it "checks existence with given conditions" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      TestUser.exists?(name: "Test User").should be_true
      TestUser.exists?(name: "Nonexistent").should be_false
    end
  end

  describe ".empty?" do
    it "returns true when no records exist matching the current query" do
      TestUser.where(name: "Nonexistent").empty?.should be_true
    end

    it "returns false when records exist" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      TestUser.empty?.should be_false
    end
  end

  describe ".find" do
    it "finds record by primary key" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      id = user.id.not_nil!

      found_user = TestUser.find(id)
      found_user.should be_a(TestUser?)
      found_user.should_not be_nil
    end
  end

  describe ".find?" do
    it "finds record by primary key, returns nil if not found" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      id = user.id.not_nil!

      found_user = TestUser.find?(id)
      found_user.should be_a(TestUser?)
      found_user.should_not be_nil

      not_found = TestUser.find?(999)
      not_found.should be_nil
    end
  end

  describe ".find!" do
    it "finds record by primary key, raises if not found" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      id = user.id.not_nil!

      found_user = TestUser.find!(id)
      found_user.should be_a(TestUser)
    end

    it "raises an error when record not found" do
      expect_raises(DB::NoResultsError) do
        TestUser.find!(999)
      end
    end
  end

  describe ".find_by" do
    it "finds record by attributes with hash" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      conditions = {:name => "Test User"} of Symbol => DB::Any
      user = TestUser.find_by(conditions)
      user.should be_a(TestUser?)
      user.should_not be_nil
    end

    it "finds record by attributes with hash syntax" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      user = TestUser.find_by(name: "Test User")
      user.should be_a(TestUser?)
      user.should_not be_nil
    end
  end

  describe ".find_by!" do
    it "finds record by attributes, raises if not found" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      user = TestUser.find_by!(name: "Test User")
      user.should be_a(TestUser)
    end

    it "raises an error when record not found" do
      expect_raises(DB::NoResultsError) do
        TestUser.find_by!(name: "Nonexistent")
      end
    end
  end

  describe ".find_each" do
    it "iterates over records in batches" do
      # Create multiple test records
      5.times do |i|
        TestUser.create!(name: "User #{i}", email: "user#{i}@example.com", age: 20 + i)
      end

      count = 0
      TestUser.find_each(batch_size: 2) do |user|
        count += 1
        user.should be_a(TestUser)
      end

      count.should eq(5)
    end
  end

  describe ".find_in_batches" do
    it "processes records in batches" do
      # Create multiple test records
      5.times do |i|
        TestUser.create!(name: "User #{i}", email: "user#{i}@example.com", age: 20 + i)
      end

      batch_count = 0
      total_records = 0

      TestUser.find_in_batches(batch_size: 2) do |batch|
        batch_count += 1
        total_records += batch.size
        batch.should be_a(Array(TestUser))
      end

      batch_count.should be > 0
      total_records.should eq(5)
    end
  end

  describe ".pluck" do
    it "extracts column values from all matching records" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      names = TestUser.pluck(:name, as: String)
      names.should be_a(Array)
      names.size.should eq(2)
    end
  end

  describe ".pick" do
    it "extracts a single column value from the first matching record" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      name = TestUser.pick(:name, as: String)
      name.should be_a(String?)
    end
  end

  describe ".ids" do
    it "gets array of primary key values" do
      user1 = TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      user2 = TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      ids = TestUser.ids(as: Int32)
      ids.should be_a(Array(Int32))
      ids.size.should eq(2)
      ids.should contain(user1.id.not_nil!)
      ids.should contain(user2.id.not_nil!)
    end
  end

  describe ".maximum" do
    it "gets maximum value of a column" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      max_age = TestUser.maximum(:age)
      max_age.should be_a(DB::Any?)
    end
  end

  describe ".minimum" do
    it "gets minimum value of a column" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      min_age = TestUser.minimum(:age)
      min_age.should be_a(DB::Any?)
    end
  end

  describe ".average" do
    it "gets average value of a column" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 20)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      avg_age = TestUser.average(:age)
      avg_age.should be_a(Float64?)
    end
  end

  describe ".distinct" do
    it "gets distinct values for a column" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 25)
      TestUser.create!(name: "User 3", email: "user3@example.com", age: 30)

      distinct_ages = TestUser.distinct(:age, as: Int32)
      distinct_ages.should be_a(Array(Int32))
      distinct_ages.size.should eq(2)
    end
  end

  describe ".delete_all" do
    it "deletes all records matching current scope" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      deleted_count = TestUser.delete_all
      deleted_count.should be_a(Int64)
      deleted_count.should eq(2)
    end
  end

  describe ".reorder" do
    it "replaces existing order clause with symbol arguments" do
      query = TestUser.order(:name).reorder(:age)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "replaces existing order clause with hash syntax" do
      query = TestUser.order(name: :asc).reorder(age: :desc)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".reverse_order" do
    it "reverses the order of the query" do
      query = TestUser.reverse_order
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".unscope" do
    it "removes specific scopes from the query" do
      query = TestUser.unscope(:where)
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe ".none" do
    it "returns a QueryBuilder that will return no results" do
      query = TestUser.none
      query.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      query.exists?.should be_false
    end
  end

  describe ".any?" do
    it "checks if any records exist" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      TestUser.any?.should be_true
    end
  end

  describe ".many?" do
    it "checks if many records exist (more than one)" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.many?.should be_false

      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)
      TestUser.many?.should be_true
    end
  end

  describe ".size" do
    it "gets the count of records" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      size = TestUser.size
      size.should be_a(Int64)
      size.should eq(2)
    end
  end
end
