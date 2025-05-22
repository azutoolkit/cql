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
      TestUser.query.should be_a(CQL::Query)
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
        query.should be_a(CQL::ActiveRecord::Queryable::Query(TestUser))
      end

      it "can be chained with other query methods" do
        query = TestUser.where(name: "Test User").where(age: 30)
        query.should be_a(CQL::ActiveRecord::Queryable::Query(TestUser))
      end
    end

    describe ".order" do
      it "returns a chainable query" do
        query = TestUser.order(name: :asc)
        query.should be_a(CQL::ActiveRecord::Queryable::Query(TestUser))
      end

      it "can be chained with other query methods" do
        query = TestUser.where(name: "Test User").order(name: :asc)
        query.should be_a(CQL::ActiveRecord::Queryable::Query(TestUser))
      end
    end

    describe ".limit" do
      it "returns a chainable query" do
        query = TestUser.limit(10)
        query.should be_a(CQL::ActiveRecord::Queryable::Query(TestUser))
      end

      it "can be chained with other query methods" do
        query = TestUser.where(name: "Test User").limit(10)
        query.should be_a(CQL::ActiveRecord::Queryable::Query(TestUser))
      end
    end

    describe ".offset" do
      it "returns a chainable query" do
        query = TestUser.offset(10)
        query.should be_a(CQL::ActiveRecord::Queryable::Query(TestUser))
      end

      it "can be chained with other query methods" do
        query = TestUser.where(name: "Test User").offset(10)
        query.should be_a(CQL::ActiveRecord::Queryable::Query(TestUser))
      end
    end

    describe ".select" do
      it "returns a chainable query" do
        query = TestUser.select(:id, :name)
        query.should be_a(CQL::ActiveRecord::Queryable::Query(TestUser))
      end

      it "can be chained with other query methods" do
        query = TestUser.where(name: "Test User").select(:id, :name)
        query.should be_a(CQL::ActiveRecord::Queryable::Query(TestUser))
      end
    end

    describe ".group_by" do
      it "returns a chainable query" do
        query = TestUser.group_by(:name)
        query.should be_a(CQL::ActiveRecord::Queryable::Query(TestUser))
      end

      it "can be chained with other query methods" do
        query = TestUser.where(name: "Test User").group_by(:name)
        query.should be_a(CQL::ActiveRecord::Queryable::Query(TestUser))
      end
    end

    # describe ".join" do
    #   it "returns a chainable query" do
    #     query = TestUser.join(:posts, {id: :user_id})
    #     query.should be_a(CQL::ActiveRecord::Queryable::Query(TestUser))
    #   end

    #   it "can be chained with other query methods" do
    #     query = TestUser.where(name: "Test User").join(:posts, {id: :user_id})
    #     query.should be_a(CQL::ActiveRecord::Queryable::Query(TestUser))
    #   end
    # end
  end
end
