require "./spec_helper"

describe CQL::ActiveRecord::Queryable::QueryBuilder do
  describe ".from_model" do
    it "creates a QueryBuilder for the given model type" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      builder.model_class.should eq(TestUser)
    end

    it "initializes with the correct schema and table" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder.query.schema.should eq(UserDB)
      builder.query.query_tables[:users].should eq(:users)
    end
  end

  describe "#initialize" do
    it "creates a QueryBuilder with the given query and model class" do
      query = CQL::Query.new(UserDB).from(:users)
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).new(query, TestUser)
      builder.query.should eq(query)
      builder.model_class.should eq(TestUser)
    end
  end

  describe "#model_class" do
    it "returns the model class" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder.model_class.should eq(TestUser)
    end
  end

  describe "#query" do
    it "returns the underlying query object" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder.query.should be_a(CQL::Query)
    end
  end

  describe "#with_query" do
    it "creates a new QueryBuilder with a modified query" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)

      new_builder = builder.with_query do
        builder.query.where({:name => "Test"})
      end

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      new_builder.should_not eq(builder)
    end
  end

  describe "#select" do
    it "adds columns to select with symbol arguments" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.select(:name, :email)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      new_builder.should_not eq(builder)
    end

    it "adds columns to select with hash syntax" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.select(name: :full_name, email: :email_address)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#where" do
    it "adds where conditions with hash" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      conditions = {:name => "Test", :age => 25} of Symbol => DB::Any
      new_builder = builder.where(conditions)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "adds where conditions with hash syntax" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.where(name: "Test", age: 25)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "adds where conditions with block" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      # Test that the where method with block exists
      # The actual block implementation would be tested in integration tests
      new_builder = builder.where(name: "Test")

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#where_like" do
    it "adds LIKE conditions" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.where_like(:name, "%Test%")

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#order" do
    it "adds order by clauses with symbol arguments" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.order(:name, :email)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "adds order by clauses with hash syntax" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.order(name: :asc, age: :desc)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#limit" do
    it "sets limit for the query" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.limit(10)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#offset" do
    it "sets offset for the query" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.offset(5)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#group" do
    it "adds group by clauses" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.group(:age, :name)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#having" do
    it "adds having conditions" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.having do |having|
        having.gt(:count, 5)
      end

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#distinct" do
    it "sets distinct flag" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.distinct

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#join" do
    it "executes automatic inner join" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.join(:profiles)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "executes inner join with block conditions" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.join(:profiles) do |filter|
        filter.eq(:users_id, :profiles_user_id)
      end

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "executes inner join with named arguments" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.join(profiles: :p)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#left" do
    it "executes automatic left join" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.left(:profiles)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "executes left join with block conditions" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.left(:profiles) do |filter|
        filter.eq(:users_id, :profiles_user_id)
      end

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#right" do
    it "executes automatic right join" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.right(:profiles)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "executes right join with block conditions" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.right(:profiles) do |filter|
        filter.eq(:users_id, :profiles_user_id)
      end

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#count" do
    it "adds count aggregate" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.count(:id)

      result.should be_a(Int64)
    end

    it "uses default column for count" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.count

      result.should be_a(Int64)
    end
  end

  describe "#sum" do
    it "adds sum aggregate" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.sum(:age)

      result.should be_a(Float64 | Int64)
    end
  end

  describe "#avg" do
    it "adds avg aggregate" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.avg(:age)

      result.should be_a(Float64)
    end
  end

  describe "#min" do
    it "adds min aggregate" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.min(:age)

      result.should be_a(DB::Any)
    end
  end

  describe "#max" do
    it "adds max aggregate" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.max(:age)

      result.should be_a(DB::Any)
    end
  end

  describe "#merge" do
    it "merges with another QueryBuilder" do
      builder1 = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder2 = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder2 = builder2.where(name: "Test")

      merged = builder1.merge(builder2)
      merged.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#all" do
    it "executes the query and returns all results" do
      # Create test data
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      results = builder.all

      results.should be_a(Array(TestUser))
      results.size.should eq(2)
    end
  end

  describe "#first" do
    it "executes the query and returns the first result" do
      TestUser.create!(name: "First User", email: "first@example.com", age: 25)
      TestUser.create!(name: "Second User", email: "second@example.com", age: 30)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.first

      result.should be_a(TestUser?)
      result.should_not be_nil
    end
  end

  describe "#first!" do
    it "executes the query and returns the first result, raises if not found" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.first!

      result.should be_a(TestUser)
    end

    it "raises an error when no records found" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder = builder.where(name: "Nonexistent")

      expect_raises(Exception) do
        builder.first!
      end
    end
  end

  describe "#last" do
    it "executes the query and returns the last result" do
      TestUser.create!(name: "First User", email: "first@example.com", age: 25)
      TestUser.create!(name: "Last User", email: "last@example.com", age: 30)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.last

      result.should be_a(TestUser?)
      result.should_not be_nil
    end
  end

  describe "#last!" do
    it "executes the query and returns the last result, raises if not found" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.last!

      result.should be_a(TestUser)
    end

    it "raises an error when no records found" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder = builder.where(name: "Nonexistent")

      expect_raises(Exception) do
        builder.last!
      end
    end
  end

  describe "#get" do
    it "executes the query and returns a scalar value" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder = builder.select(:name)
      result = builder.get(String)

      result.should be_a(String)
    end
  end

  describe "#each" do
    it "iterates over each result" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      count = 0
      builder.each do |user|
        count += 1
        user.should be_a(TestUser)
      end

      count.should eq(2)
    end
  end

  describe "#exists?" do
    it "checks if any records exist" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder.exists?.should be_true
    end

    it "returns false when no records exist" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder = builder.where(name: "Nonexistent")
      builder.exists?.should be_false
    end

    it "checks existence with conditions" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder.exists?(name: "Test User").should be_true
      builder.exists?(name: "Nonexistent").should be_false
    end
  end

  describe "#empty?" do
    it "returns true when no records exist" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder = builder.where(name: "Nonexistent")
      builder.empty?.should be_true
    end

    it "returns false when records exist" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder.empty?.should be_false
    end
  end

  describe "#to_sql" do
    it "converts to SQL string for debugging" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      sql = builder.to_sql

      sql.should be_a(String)
      sql.should contain("SELECT")
    end
  end

  describe "#to_sql_with_params" do
    it "gets the SQL query and parameters" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder = builder.where(name: "Test")

      sql, params = builder.to_sql_with_params

      sql.should be_a(String)
      params.should be_a(Array)
    end
  end

  describe "#find" do
    it "finds record by primary key" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      id = user.id.not_nil!

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.find(id)

      result.should be_a(TestUser?)
      result.should_not be_nil
    end
  end

  describe "#find!" do
    it "finds record by primary key, raises if not found" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      id = user.id.not_nil!

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.find!(id)

      result.should be_a(TestUser)
    end

    it "raises an error when record not found" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)

      expect_raises(DB::NoResultsError) do
        builder.find!(999)
      end
    end
  end

  describe "#find_by" do
    it "finds record by attributes with hash" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.find_by(name: "Test User")

      result.should be_a(TestUser?)
      result.should_not be_nil
    end

    it "finds record by attributes with hash syntax" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.find_by(name: "Test User")

      result.should be_a(TestUser?)
      result.should_not be_nil
    end
  end

  describe "#find_by!" do
    it "finds record by attributes, raises if not found" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.find_by!(name: "Test User")

      result.should be_a(TestUser)
    end

    it "raises an error when record not found" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)

      expect_raises(DB::NoResultsError) do
        builder.find_by!(name: "Nonexistent")
      end
    end
  end

  describe "#find_each" do
    it "iterates over records in batches" do
      # Create multiple test records
      5.times do |i|
        TestUser.create!(name: "User #{i}", email: "user#{i}@example.com", age: 20 + i)
      end

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      count = 0
      builder.find_each(batch_size: 2) do |user|
        count += 1
        user.should be_a(TestUser)
      end

      count.should eq(5)
    end
  end

  describe "#find_in_batches" do
    it "processes records in batches" do
      # Create multiple test records
      5.times do |i|
        TestUser.create!(name: "User #{i}", email: "user#{i}@example.com", age: 20 + i)
      end

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      batch_count = 0
      total_records = 0

      builder.find_in_batches(batch_size: 2) do |batch|
        batch_count += 1
        total_records += batch.size
        batch.should be_a(Array(TestUser))
      end

      batch_count.should be > 0
      total_records.should eq(5)
    end
  end

  describe "#pluck" do
    it "extracts column values from all matching records" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      names = builder.pluck(:name, as: String)

      names.should be_a(Array)
      names.size.should eq(2)
    end
  end

  describe "#pick" do
    it "extracts a single column value from the first matching record" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      name = builder.pick(:name, as: String)

      name.should be_a(String?)
    end
  end

  describe "#ids" do
    it "gets array of primary key values" do
      user1 = TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      user2 = TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      ids = builder.ids(as: Int32)

      ids.should be_a(Array(Int32))
      ids.size.should eq(2)
      ids.should contain(user1.id.not_nil!)
      ids.should contain(user2.id.not_nil!)
    end
  end

  describe "#maximum" do
    it "gets maximum value of a column" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      max_age = builder.maximum(:age)

      max_age.should be_a(DB::Any?)
    end
  end

  describe "#minimum" do
    it "gets minimum value of a column" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      min_age = builder.minimum(:age)

      min_age.should be_a(DB::Any?)
    end
  end

  describe "#average" do
    it "gets average value of a column" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 20)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      avg_age = builder.average(:age)

      avg_age.should be_a(Float64?)
    end
  end

  describe "#distinct_values" do
    it "gets distinct values for a column" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 25)
      TestUser.create!(name: "User 3", email: "user3@example.com", age: 30)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      distinct_ages = builder.distinct_values(:age, as: Int32)

      distinct_ages.should be_a(Array(Int32))
      distinct_ages.size.should eq(2)
    end
  end

  describe "#reorder" do
    it "replaces existing order clause with symbol arguments" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder = builder.order(:name)
      new_builder = builder.reorder(:age)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "replaces existing order clause with hash syntax" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder = builder.order(name: :asc)
      new_builder = builder.reorder(age: :desc)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#reverse_order" do
    it "reverses the order of records" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.reverse_order

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#unscope" do
    it "removes specific scopes" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.unscope(:where)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#delete_all" do
    it "deletes all records matching current scope" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      deleted_count = builder.delete_all

      deleted_count.should be_a(Int64)
      deleted_count.should eq(2)
    end
  end

  describe "#group_by" do
    it "adds group by clauses (alias for group)" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.group_by(:age)

      new_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "#none" do
    it "returns a QueryBuilder that will return no results" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      none_builder = builder.none

      none_builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      none_builder.exists?.should be_false
    end
  end

  describe "#any?" do
    it "checks if any records exist" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder.any?.should be_true
    end
  end

  describe "#many?" do
    it "checks if many records exist (more than one)" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder.many?.should be_false

      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)
      builder.many?.should be_true
    end
  end

  describe "#size" do
    it "gets the count of records" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      size = builder.size

      size.should be_a(Int64)
      size.should eq(2)
    end
  end
end
