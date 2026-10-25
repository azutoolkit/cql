require "./spec_helper"

# Counts the statements it runs, then delegates to the schema.
private class CountingCountExecutor
  include CQL::Executor

  getter statements = 0

  def initialize(@schema : CQL::Schema)
  end

  def adapter : CQL::Adapter
    @schema.adapter
  end

  def exec_query(& : DB::Connection -> _)
    @statements += 1
    @schema.exec_query { |connection| yield connection }
  end
end

private class LastSoftDeletableUser
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::SoftDeletable

  db_context schema: SoftDeletableDB, table: :users

  property name : String
  property email : String
  property age : Int32 = 0

  def initialize(@name, @email, @age = 0)
  end
end

private def create_last_user(name : String, age : Int32)
  TestUser.create!(name: name, email: "#{name.downcase}@example.com", age: age, password: "password123", password_confirmation: "password123")
end

private def create_last_users
  create_last_user("Bravo", 30)
  create_last_user("Alpha", 40)
  create_last_user("Charlie", 30)
end

describe CQL::ActiveRecord::Queryable::QueryBuilder do
  before_each do
    UserDB.users.create!
  end

  after_each do
    UserDB.users.drop!
  end
  describe ".from_model" do
    it "creates a QueryBuilder for the given model type" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      builder.model_class.should eq(TestUser)
    end

    it "initializes with the correct schema and table" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder.query.schema.should eq(UserDB)
      builder.query.query_tables["users"].should be_a(CQL::Query::QueryTableInfo)
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
      new_builder = builder.select(name: :user_name, email: :email_address)

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
    pending "adds having conditions" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      new_builder = builder.having do
        count(:id) > 5
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

    pending "executes inner join with block conditions" do
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

    pending "executes left join with block conditions" do
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

    pending "executes right join with block conditions" do
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

    describe "with five rows" do
      before_each do
        5.times do |i|
          TestUser.create!(name: "User #{i}", email: "count#{i}@example.com", age: 20 + i, password: "password123", password_confirmation: "password123")
        end
      end

      it "counts all rows and filtered rows" do
        TestUser.query.count.should eq(5)
        TestUser.query.where(name: "User 1").count.should eq(1)
        TestUser.query.where { age >= 22 }.count.should eq(3)
      end

      it "counts all rows without an ORDER BY clause" do
        count_statements = [] of String
        CQL::Telemetry.subscribe("query_builder_count") do |event|
          count_statements << event.sql if event.sql.includes?("COUNT(")
        end

        begin
          TestUser.query.order(name: :desc).count.should eq(5)
        ensure
          CQL::Telemetry.unsubscribe("query_builder_count")
        end

        count_statements.size.should eq(1)
        count_statements.first.should_not contain("ORDER BY")
      end

      it "returns at most the limit" do
        TestUser.query.limit(2).count.should eq(2)
      end

      it "counts the rows remaining after the offset" do
        TestUser.query.offset(2).limit(5).count.should eq(3)
      end

      it "returns zero when the offset is past the last row" do
        TestUser.query.offset(5).limit(5).count.should eq(0)
      end

      it "counts the rows remaining after an offset without a limit" do
        TestUser.query.offset(2).count.should eq(3)
      end

      it "counts only non-NULL values of the given column within the limit" do
        TestUser.create!(name: nil, email: "nameless@example.com", age: 30, password: "password123", password_confirmation: "password123")

        TestUser.query.limit(10).count(:name).should eq(5)
      end

      it "orders the window before counting non-NULL values of a column" do
        TestUser.create!(name: nil, email: "nameless@example.com", age: 19, password: "password123", password_confirmation: "password123")

        TestUser.query.order(:age).limit(2).count(:name).should eq(1)
      end

      it "counts the groups inside the window" do
        TestUser.create!(name: "Twin", email: "twin@example.com", age: 20, password: "password123", password_confirmation: "password123")

        TestUser.query.group(:age).limit(2).count.should eq(2)
        TestUser.query.group(:age).limit(10).count.should eq(5)
      end

      it "runs a limited count on the pinned executor" do
        executor = CountingCountExecutor.new(UserDB)

        TestUser.query.using(executor).limit(2).count.should eq(2)
        executor.statements.should eq(1)
      end
    end

    describe "#count_query" do
      it "binds the where value before LIMIT and OFFSET on PostgreSQL" do
        query = TestUser.query.where(name: "a").limit(2).offset(1).count_query

        query.to_sql(Expression::Generator.new(CQL::Adapter::Postgres)).should eq({
          "SELECT COUNT(*) FROM (SELECT users.id FROM users WHERE users.name = $1 LIMIT $2 OFFSET $3) AS counted_rows",
          ["a", 2, 1],
        })
      end

      it "binds the where value before LIMIT and OFFSET on MySQL" do
        query = TestUser.query.where(name: "a").limit(2).offset(1).count_query

        query.to_sql(Expression::Generator.new(CQL::Adapter::MySql)).should eq({
          "SELECT COUNT(*) FROM (SELECT users.id FROM users WHERE users.name = ? LIMIT ? OFFSET ?) AS counted_rows",
          ["a", 2, 1],
        })
      end

      it "keeps ORDER BY inside the derived table when counting a column on PostgreSQL" do
        query = TestUser.query.order(:age).limit(2).count_query(:name)

        query.to_sql(Expression::Generator.new(CQL::Adapter::Postgres)).should eq({
          "SELECT COUNT(counted_rows.name) FROM (SELECT users.name FROM users ORDER BY users.age ASC LIMIT $1) AS counted_rows",
          [2],
        })
      end

      it "drops ORDER BY from the derived table when counting all rows on PostgreSQL" do
        query = TestUser.query.order(:age).limit(2).count_query

        query.to_sql(Expression::Generator.new(CQL::Adapter::Postgres)).should eq({
          "SELECT COUNT(*) FROM (SELECT users.id FROM users LIMIT $1) AS counted_rows",
          [2],
        })
      end

      it "selects the group-by columns inside a grouped limited count on PostgreSQL" do
        query = TestUser.query.group(:age).limit(2).count_query

        query.to_sql(Expression::Generator.new(CQL::Adapter::Postgres)).should eq({
          "SELECT COUNT(*) FROM (SELECT users.age FROM users GROUP BY users.age LIMIT $1) AS counted_rows",
          [2],
        })
      end

      it "selects only the primary key inside a joined limited count on MySQL" do
        query = TestUser.query.join(:posts).limit(2).count_query

        query.to_sql(Expression::Generator.new(CQL::Adapter::MySql)).should eq({
          "SELECT COUNT(*) FROM (SELECT users.id FROM users INNER JOIN posts ON posts.user_id = users.id LIMIT ?) AS counted_rows",
          [2],
        })
      end
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
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25, password: "password123", password_confirmation: "password123")
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      results = builder.all

      results.should be_a(Array(TestUser))
      results.size.should eq(2)
    end
  end

  describe "#first" do
    it "executes the query and returns the first result" do
      TestUser.create!(name: "First User", email: "first@example.com", age: 25, password: "password123", password_confirmation: "password123")
      TestUser.create!(name: "Second User", email: "second@example.com", age: 30, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.first

      result.should be_a(TestUser?)
      result.should_not be_nil
    end
  end

  describe "#first!" do
    it "executes the query and returns the first result, raises if not found" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25, password: "password123", password_confirmation: "password123")

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
      TestUser.create!(name: "First User", email: "first@example.com", age: 25, password: "password123", password_confirmation: "password123")
      TestUser.create!(name: "Last User", email: "last@example.com", age: 30, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.last

      result.should be_a(TestUser?)
      result.should_not be_nil
    end
  end

  describe "#last without loading every row" do
    it "returns the highest-id record with a single LIMIT ... DESC select from the model" do
      create_last_users
      newest = TestUser.query.order(:id).all.last

      result = nil
      statements = count_queries { result = TestUser.last }

      result.try(&.id).should eq(newest.id)
      statements.size.should eq(1)
      statements.first.should contain("LIMIT")
      statements.first.should contain("DESC")
    end

    it "returns the highest-id record with a single LIMIT ... DESC select from the builder" do
      create_last_users
      newest = TestUser.query.order(:id).all.last

      result = nil
      statements = count_queries { result = TestUser.query.last }

      result.try(&.id).should eq(newest.id)
      statements.size.should eq(1)
      statements.first.should contain("LIMIT")
      statements.first.should contain("DESC")
    end

    it "reverses a custom order and keeps the old result" do
      create_last_users

      result = nil
      statements = count_queries { result = TestUser.query.order(name: :asc).last }

      result.try(&.name).should eq("Charlie")
      statements.size.should eq(1)
      statements.first.should match(/ORDER BY\s+"?(\w+"?\.)?"?name"?\s+DESC/i)
      statements.first.should contain("LIMIT ?")
    end

    it "reverses a multi-column order column by column" do
      create_last_users

      result = nil
      statements = count_queries { result = TestUser.query.order(age: :asc, name: :desc).last }

      result.try(&.name).should eq("Alpha")
      statements.size.should eq(1)
      statements.first.should match(/age"?\s+DESC,\s*"?(\w+"?\.)?"?name"?\s+ASC/i)
      statements.first.should contain("LIMIT ?")
    end

    it "keeps the old semantics when the query has a limit" do
      create_last_users

      TestUser.query.order(:id).limit(2).last.try(&.name).should eq("Alpha")
    end

    it "keeps the old semantics when the query has an offset or distinct" do
      create_last_users

      TestUser.query.order(:id).offset(1).last.try(&.name).should eq("Charlie")
      TestUser.query.order(:id).distinct.last.try(&.name).should eq("Charlie")
    end

    it "returns nil for an empty table" do
      TestUser.last.should be_nil
      TestUser.query.last.should be_nil
    end

    it "returns the last row of a partial select with a single LIMIT 1 select" do
      create_last_users
      newest = TestUser.query.order(:id).all.last

      result = nil
      statements = count_queries { result = TestUser.query.select(:id, :name).last }

      result.try(&.id).should eq(newest.id)
      result.try(&.name).should eq("Charlie")
      statements.size.should eq(1)
      statements.first.should contain("LIMIT ?")
      statements.first.should contain("DESC")
    end

    it "breaks ties on the order by the primary key, so the later insert is last" do
      create_last_user("Bravo", 30)
      create_last_user("Delta", 30)

      result = nil
      statements = count_queries { result = TestUser.query.order(age: :asc).last }

      result.try(&.name).should eq("Delta")
      statements.first.should match(/age"?\s+DESC,\s*"?(\w+"?\.)?"?id"?\s+DESC/i)
    end

    it "orders a join without a select by the table-qualified primary key" do
      UserDB.posts.create!
      [create_last_user("Author", 30), create_last_user("Newest", 40)].each do |user|
        Post.create!(title: "Post", body: "Body", user_id: user.id)
      end

      result = nil
      statements = count_queries { result = TestUser.query.join(:posts).last }

      result.try(&.name).should eq("Newest")
      statements.size.should eq(1)
      statements.first.should contain("ORDER BY users.id DESC LIMIT ?")
    ensure
      UserDB.posts.drop!
    end

    it "keeps the soft-delete filter and skips a soft-deleted newest row" do
      SoftDeletableDB.users.create!
      kept = LastSoftDeletableUser.new("Kept", "kept@example.com")
      kept.create!
      LastSoftDeletableUser.new("Deleted", "deleted@example.com").tap(&.create!).delete!

      result = nil
      statements = count_queries { result = LastSoftDeletableUser.last }

      result.try(&.id).should eq(kept.id)
      statements.first.should contain("deleted_at IS NULL")
    ensure
      SoftDeletableDB.users.drop!
    end

    it "returns the last row from last! on both builders and raises when empty" do
      expect_raises(Exception, "No records found") { TestUser.query.last! }
      expect_raises(Exception, "No records found") { TestUser.query.select(:id, :name).last! }

      create_last_users

      TestUser.query.last!.name.should eq("Charlie")
      TestUser.query.select(:id, :name).last!.name.should eq("Charlie")
    end

    it "loads every row when the query is grouped" do
      create_last_users

      result = nil
      statements = count_queries { result = TestUser.query.select(:age).group(:age).order(:age).last }

      result.try(&.age).should eq(40)
      statements.first.should_not contain("LIMIT")
    end

    it "loads every row when the query selects an aggregate" do
      create_last_users

      result = nil
      statements = count_queries { result = TestUser.query.select(max: :age).last(as: Int32) }

      result.should eq(40)
      statements.first.should_not contain("ORDER BY")
    end
  end

  describe "#last!" do
    it "executes the query and returns the last result, raises if not found" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25, password: "password123", password_confirmation: "password123")

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
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder = builder.select(:name)
      result = builder.get(String)

      result.should be_a(String)
    end
  end

  describe "#each" do
    it "iterates over each result" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25, password: "password123", password_confirmation: "password123")
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      count = 0
      builder.each do |user|
        count += 1
        user.should be_a(TestUser)
      end

      count.should eq(2)
    end

    it "yields models in query order and stops at a break" do
      %w[Ada Bo Cy].each_with_index { |name, i| create_last_user(name, 20 + i) }

      names = [] of String
      TestUser.query.order(age: :asc).each do |user|
        names << user.name.not_nil!
        break if names.size == 2
      end

      names.should eq(%w[Ada Bo])
      UserDB.pool_stats.in_flight.should eq(0)
      TestUser.query.order(age: :asc).all.map(&.name).should eq(%w[Ada Bo Cy])
    end

    it "releases the connection when the block raises" do
      create_last_user("Ada", 20)

      expect_raises(Exception, "boom") { TestUser.query.each { |_| raise "boom" } }

      UserDB.pool_stats.in_flight.should eq(0)
      TestUser.count.should eq(1)
    end
  end

  describe "#exists?" do
    it "checks if any records exist" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder.exists?.should be_true
    end

    it "returns false when no records exist" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder = builder.where(name: "Nonexistent")
      builder.exists?.should be_false
    end

    it "checks existence with conditions" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25, password: "password123", password_confirmation: "password123")

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
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder.empty?.should be_false
    end
  end

  describe "existence checks without counting" do
    it "answers exists? and any? with one LIMIT select and no COUNT" do
      create_last_user("Alpha", 30)

      results = [] of Bool
      statements = count_queries do
        results << TestUser.query.where(name: "Alpha").exists?
        results << TestUser.query.where(name: "Alpha").any?
        results << TestUser.query.exists?(name: "Alpha")
        results << TestUser.exists?(name: "Alpha")
        results << TestUser.exists?
      end

      results.should eq([true] * 5)
      statements.size.should eq(5)
      statements.each do |sql|
        sql.should contain("LIMIT ?")
        sql.should_not contain("COUNT(")
      end
    end

    it "returns false with the same SQL shape when nothing matches" do
      results = [] of Bool
      statements = count_queries do
        results << TestUser.query.where(name: "Nobody").exists?
        results << TestUser.query.where(name: "Nobody").any?
        results << TestUser.exists?(name: "Nobody")
        results << TestUser.exists?
      end

      results.should eq([false] * 4)
      statements.size.should eq(4)
      statements.each do |sql|
        sql.should contain("LIMIT ?")
        sql.should_not contain("COUNT(")
      end
    end

    it "reflects whether a row exists past the offset" do
      create_last_users

      results = [] of Bool
      statements = count_queries do
        results << TestUser.query.order(:id).offset(2).exists?
        results << TestUser.query.order(:id).offset(3).exists?
      end

      results.should eq([true, false])
      statements.each do |sql|
        sql.should contain("LIMIT ?")
        sql.should_not contain("COUNT(")
      end
    end

    it "makes many? false for zero or one row and true for two or more with one LIMIT select" do
      outcomes = [] of Bool
      statements = [] of String

      statements.concat count_queries { outcomes << TestUser.query.many? }
      create_last_user("Alpha", 30)
      statements.concat count_queries { outcomes << TestUser.query.many? }
      create_last_user("Bravo", 30)
      statements.concat count_queries { outcomes << TestUser.query.many? }
      create_last_user("Charlie", 30)
      statements.concat count_queries { outcomes << TestUser.query.where(age: 30).many? }
      statements.concat count_queries { outcomes << TestUser.many? }

      outcomes.should eq([false, false, true, true, true])
      statements.size.should eq(5)
      statements.each do |sql|
        sql.should contain("LIMIT ?")
        sql.should_not contain("COUNT(")
      end
    end

    it "respects the query's own limit and offset" do
      create_last_users

      TestUser.query.limit(0).exists?.should be_false
      TestUser.query.limit(1).many?.should be_false
      TestUser.query.limit(5).offset(2).exists?.should be_true
      TestUser.query.limit(5).offset(2).many?.should be_false
    end

    it "counts groups, not rows, for a grouped query" do
      create_last_user("Bravo", 30)
      create_last_user("Charlie", 30)

      TestUser.query.group(:age).exists?.should be_true
      TestUser.query.group(:age).many?.should be_false

      create_last_user("Alpha", 40)

      TestUser.query.group(:age).many?.should be_true
      TestUser.query.where(name: "Nobody").group(:age).exists?.should be_false
    end

    it "checks a distinct query" do
      TestUser.query.distinct.exists?.should be_false
      create_last_user("Alpha", 30)
      TestUser.query.distinct.exists?.should be_true
    end

    it "selects the table-qualified primary key for a join" do
      UserDB.posts.create!
      author = create_last_user("Author", 30)
      create_last_user("Silent", 40)

      TestUser.query.join(:posts).exists?.should be_false
      Post.create!(title: "Post", body: "Body", user_id: author.id)

      result = false
      statements = count_queries { result = TestUser.query.join(:posts).exists? }

      result.should be_true
      statements.size.should eq(1)
      statements.first.should contain("SELECT users.id FROM users INNER JOIN posts")
      statements.first.should contain("LIMIT ?")
    ensure
      UserDB.posts.drop!
    end

    it "ignores soft-deleted rows in Model.exists?" do
      SoftDeletableDB.users.create!
      LastSoftDeletableUser.new("Deleted", "deleted@example.com").tap(&.create!).delete!

      LastSoftDeletableUser.exists?.should be_false
      LastSoftDeletableUser.exists?(name: "Deleted").should be_false

      LastSoftDeletableUser.new("Kept", "kept@example.com").create!

      LastSoftDeletableUser.exists?.should be_true
      LastSoftDeletableUser.exists?(name: "Kept").should be_true
      LastSoftDeletableUser.exists?(name: "Deleted").should be_false
    ensure
      SoftDeletableDB.users.drop!
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
      params.should be_a(Array(DB::Any))
    end
  end

  describe "#find" do
    it "finds record by primary key" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25, password: "password123")
      id = user.id.not_nil!

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.find(id)

      result.should be_a(TestUser?)
      result.should_not be_nil
    end
  end

  describe "#find!" do
    it "finds record by primary key, raises if not found" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25, password: "password123")
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
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.find_by(name: "Test User")

      result.should be_a(TestUser?)
      result.should_not be_nil
    end

    it "finds record by attributes with hash syntax" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      result = builder.find_by(name: "Test User")

      result.should be_a(TestUser?)
      result.should_not be_nil
    end
  end

  describe "#find_by!" do
    it "finds record by attributes, raises if not found" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25, password: "password123", password_confirmation: "password123")

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
        TestUser.create!(name: "User #{i}", email: "user#{i}@example.com", age: 20 + i, password: "password123", password_confirmation: "password123")
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
        TestUser.create!(name: "User #{i}", email: "user#{i}@example.com", age: 20 + i, password: "password123", password_confirmation: "password123")
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

  describe "keyset batching" do
    it "yields every row exactly once in id order from #find_each" do
      ids = (1..7).map { |i| create_last_user("User#{i}", 20 + i).id!.to_i64 }

      yielded = [] of Int64
      TestUser.query.find_each(batch_size: 3) { |user| yielded << user.id!.to_i64 }

      yielded.should eq(ids)
    end

    it "yields batches of [3, 3, 1] from #find_in_batches" do
      7.times { |i| create_last_user("User#{i}", 20 + i) }

      sizes = [] of Int32
      TestUser.query.find_in_batches(batch_size: 3) { |batch| sizes << batch.size }

      sizes.should eq([3, 3, 1])
    end

    it "pages by primary key without OFFSET, one SELECT per batch" do
      7.times { |i| create_last_user("User#{i}", 20 + i) }

      statements = count_queries do
        TestUser.query.find_each(batch_size: 3) { |_| }
      end

      statements.size.should eq(3)
      statements[1..].each do |sql|
        sql.should match(/\bid\s*>\s*\?/i)
        sql.should match(/ORDER BY\s+\S*\bid\b\S*\s+ASC/i)
        sql.should match(/LIMIT\s+\?/i)
      end
      statements.each(&.should_not(match(/OFFSET/i)))
    end

    it "confirms the end with one empty fetch" do
      6.times { |i| create_last_user("User#{i}", 20 + i) }

      statements = count_queries do
        TestUser.query.find_in_batches(batch_size: 3) { |_| }
      end

      # two full batches, then one empty fetch to confirm the end
      statements.size.should eq(3)
    end

    it "skips a not-yet-visited row deleted mid-iteration" do
      ids = (1..7).map { |i| create_last_user("User#{i}", 20 + i).id!.to_i64 }

      yielded = [] of Int64
      TestUser.query.find_each(batch_size: 3) do |user|
        TestUser.find!(ids[4].to_i32).delete! if yielded.empty?
        yielded << user.id!.to_i64
      end

      yielded.should eq(ids - [ids[4]])
    end

    it "does not skip rows when an already-visited row is deleted mid-iteration" do
      ids = (1..7).map { |i| create_last_user("User#{i}", 20 + i).id!.to_i64 }

      yielded = [] of Int64
      TestUser.query.find_each(batch_size: 3) do |user|
        TestUser.find!(ids[0].to_i32).delete! if user.id!.to_i64 == ids[2]
        yielded << user.id!.to_i64
      end

      yielded.should eq(ids)
    end

    it "only yields rows matching the where scope" do
      ages = [30, 40, 30, 30, 40, 30, 30]
      matching = ages.map_with_index { |age, i| {create_last_user("User#{i}", age).id!.to_i64, age} }
        .select { |_, age| age == 30 }.map(&.first)

      yielded = [] of Int64
      TestUser.query.where(age: 30).find_each(batch_size: 2) { |user| yielded << user.id!.to_i64 }

      yielded.should eq(matching)
    end

    it "visits every row exactly once when the query has its own ORDER BY" do
      names = %w[Delta Alpha Echo Bravo Foxtrot Charlie Golf]
      names.each_with_index { |name, i| create_last_user(name, 20 + i) }

      yielded = [] of String
      TestUser.query.order(name: :desc).find_each(batch_size: 3) { |user| yielded << user.name.to_s }

      yielded.should eq(names.sort.reverse!)
    end

    it "ignores the query's offset, yielding every row exactly once" do
      ids = (1..7).map { |i| create_last_user("User#{i}", 20 + i).id!.to_i64 }

      yielded = [] of Int64
      TestUser.query.offset(2).find_each(batch_size: 2) { |user| yielded << user.id!.to_i64 }

      yielded.should eq(ids)
    end

    it "yields a parent with several joined children once" do
      UserDB.posts.create!
      author = create_last_user("Author", 30)
      reader = create_last_user("Reader", 40)
      3.times { Post.create!(title: "Post", body: "Body", user_id: author.id) }
      Post.create!(title: "Post", body: "Body", user_id: reader.id)

      [1, 2].each do |batch_size|
        yielded = [] of Int64
        TestUser.query.join(:posts).find_each(batch_size: batch_size) { |user| yielded << user.id!.to_i64 }

        yielded.should eq([author.id!.to_i64, reader.id!.to_i64])
      end
    ensure
      UserDB.posts.drop!
    end

    it "breaks ties in the query's ORDER BY by primary key, visiting every row exactly once" do
      ids = [30, 20, 30, 20, 30, 20, 30].map_with_index { |age, i| create_last_user("User#{i}", age).id!.to_i64 }

      yielded = [] of Int64
      statements = count_queries do
        TestUser.query.order(age: :asc).find_each(batch_size: 2) { |user| yielded << user.id!.to_i64 }
      end

      yielded.sort.should eq(ids)
      yielded.uniq.size.should eq(ids.size)
      statements.each(&.should(match(/ORDER BY\s+\S*age\S*\s+ASC,\s*\S*\bid\b\S*\s+ASC/i)))
    end

    it "pages a shaped query by OFFSET" do
      ids = (1..5).map { |i| create_last_user("User#{i}", 20 + i).id!.to_i64 }

      yielded = [] of Int64
      statements = count_queries do
        TestUser.query.distinct.find_each(batch_size: 2) { |user| yielded << user.id!.to_i64 }
      end

      yielded.should eq(ids)
      statements[1..].each(&.should(match(/OFFSET/i)))
    end

    it "raises ArgumentError for a zero batch_size" do
      expect_raises(ArgumentError) { TestUser.query.find_each(batch_size: 0) { |_| } }
    end

    it "keeps an OR condition scoped on every page" do
      ages = [20, 30, 40, 50, 60, 70]
      matching = ages.map { |age| {create_last_user("User#{age}", age).id!.to_i64, age} }
        .select { |_, age| age < 25 || age > 55 }.map(&.first)

      yielded = [] of Int64
      TestUser.query.where { (age < 25) | (age > 55) }.find_each(batch_size: 1) { |user| yielded << user.id!.to_i64 }

      yielded.should eq(matching)
    end
  end

  describe "#pluck" do
    it "extracts column values from all matching records" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25, password: "password123", password_confirmation: "password123")
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      names = builder.pluck(:name, as: String)

      names.should be_a(Array(String))
      names.size.should eq(2)
    end
  end

  describe "#pick" do
    it "extracts a single column value from the first matching record" do
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      name = builder.pick(:name, as: String)

      name.should be_a(String?)
    end
  end

  describe "#ids" do
    it "gets array of primary key values" do
      user1 = TestUser.create!(name: "User 1", email: "user1@example.com", age: 25, password: "password123")
      user2 = TestUser.create!(name: "User 2", email: "user2@example.com", age: 30, password: "password123")

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
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25, password: "password123", password_confirmation: "password123")
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      max_age = builder.maximum(:age)

      max_age.should be_a(DB::Any?)
    end
  end

  describe "#minimum" do
    it "gets minimum value of a column" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25, password: "password123", password_confirmation: "password123")
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      min_age = builder.minimum(:age)

      min_age.should be_a(DB::Any?)
    end
  end

  describe "#average" do
    it "gets average value of a column" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 20, password: "password123", password_confirmation: "password123")
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      avg_age = builder.average(:age)

      avg_age.should be_a(Float64?)
    end
  end

  describe "#distinct_values" do
    it "gets distinct values for a column" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25, password: "password123", password_confirmation: "password123")
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 25, password: "password123", password_confirmation: "password123")
      TestUser.create!(name: "User 3", email: "user3@example.com", age: 30, password: "password123", password_confirmation: "password123")

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
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25, password: "password123", password_confirmation: "password123")
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      deleted_count = builder.delete_all

      deleted_count.should be_a(Int64)
      deleted_count.should eq(2)
    end

    it "runs each record's destroy callbacks when the model declares them" do
      create_last_user("Ada", 30)
      create_last_user("Linus", 40)
      CallbackTracker.clear

      TestUser.where(age: 30).delete_all.should eq(1)

      CallbackTracker.order.count("before_destroy").should eq(1)
      CallbackTracker.order.count("after_destroy").should eq(1)
      TestUser.all.map(&.name).should eq(["Linus"])
    end

    it "deletes by id in one SELECT and one DELETE when the model has no destroy callbacks" do
      UserDB.posts.create!
      3.times { |i| Post.create!(title: "Gone #{i}", body: "gone") }
      kept = Post.create!(title: "Kept", body: "kept")

      deleted = 0_i64
      selects = [] of String
      deletes = count_queries(:delete) { selects = count_queries { deleted = Post.where(body: "gone").delete_all } }

      deleted.should eq(3)
      selects.size.should eq(1)
      deletes.size.should eq(1)
      Post.all.map(&.id!).should eq([kept.id!])
    ensure
      UserDB.posts.drop!
    end

    it "splits the DELETE into chunks within the bind limit" do
      UserDB.posts.create!
      count = Post.adapter.dialect.max_bind_params
      Post.insert_all((1..count).map { |i| {title: "P#{i}", body: "bulk"} })

      deleted = 0_i64
      deletes = count_queries(:delete) { deleted = Post.where(body: "bulk").delete_all }

      deleted.should eq(count)
      deletes.size.should eq(2)
      Post.count.should eq(0)
    ensure
      UserDB.posts.drop!
    end

    it "deletes only the rows a limit and order select" do
      UserDB.posts.create!
      %w[c a b].each { |title| Post.create!(title: title, body: "b") }

      Post.order(title: :asc).limit(2).delete_all.should eq(2)

      Post.all.map(&.title).should eq(["c"])
    ensure
      UserDB.posts.drop!
    end

    it "runs no DELETE when nothing matches" do
      UserDB.posts.create!
      Post.create!(title: "Kept", body: "kept")

      count_queries(:delete) { Post.where(body: "none").delete_all.should eq(0) }.should be_empty
      Post.count.should eq(1)
    ensure
      UserDB.posts.drop!
    end

    it "deletes only the rows a join condition selects" do
      UserDB.posts.create!
      ada = create_last_user("Ada", 30)
      bob = create_last_user("Bob", 40)
      2.times { |i| Post.create!(title: "Ada #{i}", body: "b", user_id: ada.id!) }
      Post.create!(title: "Bob", body: "b", user_id: bob.id!)

      Post.query.joins(:user) { user.name == "Ada" }.delete_all.should eq(2)

      Post.all.map(&.title).should eq(["Bob"])
    ensure
      UserDB.posts.drop!
    end

    it "reports which models declare destroy callbacks" do
      TestUser.destroy_callbacks?.should be_true
      Post.destroy_callbacks?.should be_false
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
      TestUser.create!(name: "Test User", email: "test@example.com", age: 25, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder.any?.should be_true
    end
  end

  describe "#many?" do
    it "checks if many records exist (more than one)" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder.many?.should be_false

      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30, password: "password123", password_confirmation: "password123")
      builder.many?.should be_true
    end
  end

  describe "#size" do
    it "gets the count of records" do
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25, password: "password123", password_confirmation: "password123")
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30, password: "password123", password_confirmation: "password123")

      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      size = builder.size

      size.should be_a(Int64)
      size.should eq(2)
    end
  end
end
