require "../spec_helper"

# Security test suite for SQL injection prevention
# Tests various injection vectors to ensure proper parameterization
describe "SQL Injection Prevention" do
  describe "Query Builder" do
    it "prevents SQL injection in WHERE clauses with hash syntax" do
      schema = CQL::Schema.define(
        :security_test,
        adapter: CQL::Adapter::SQLite,
        uri: "sqlite3::memory:"
      ) do
        table :users do
          primary :id, Int64
          text :username
          text :email
        end
      end

      schema.users.create!

      # Attempt SQL injection via username
      malicious_input = "admin' OR '1'='1"

      # Should treat as literal string, not SQL
      query = schema.query
        .from(:users)
        .where(username: malicious_input)

      sql, params = query.to_sql

      # Verify the query uses parameterization
      sql.should contain("?")
      params.should eq([malicious_input])

      # Execute should return no results (no user with that exact string)
      users = query.all(Hash(String, DB::Any))
      users.should be_empty
    end

    it "prevents SQL injection with numeric comparisons" do
      schema = CQL::Schema.define(
        :security_test2,
        adapter: CQL::Adapter::SQLite,
        uri: "sqlite3::memory:"
      ) do
        table :users do
          primary :id, Int64
          text :username
        end
      end

      schema.users.create!

      # Attempt UNION-based injection via ID
      # Using a string that looks like SQL
      malicious_id = "1 OR 1=1"

      # When used with WHERE hash, should be parameterized
      query = schema.query
        .from(:users)
        .where(username: malicious_id)

      sql, params = query.to_sql

      # Verify parameterization
      sql.should contain("?")
      params.should eq([malicious_id])
      # The malicious SQL shouldn't be in the query structure
      sql.should_not contain("OR 1=1")
    end

    it "prevents SQL injection in LIKE clauses" do
      schema = CQL::Schema.define(
        :security_test3,
        adapter: CQL::Adapter::SQLite,
        uri: "sqlite3::memory:"
      ) do
        table :users do
          primary :id, Int64
          text :email
        end
      end

      schema.users.create!

      # Attempt injection via LIKE pattern
      malicious_pattern = "%' OR '1'='1"

      query = schema.query
        .from(:users)
        .where_like(:email, malicious_pattern)

      sql, params = query.to_sql

      # Should be parameterized
      sql.should contain("LIKE ?")
      params.should eq([malicious_pattern])
    end

    it "prevents SQL injection with IN clauses" do
      schema = CQL::Schema.define(
        :security_test4,
        adapter: CQL::Adapter::SQLite,
        uri: "sqlite3::memory:"
      ) do
        table :users do
          primary :id, Int64
          text :username
        end
      end

      schema.users.create!

      # Attempt injection via array
      malicious_ids = [1, 2, "3) OR 1=1--"]

      query = schema.query
        .from(:users)
        .where(id: malicious_ids)

      sql, params = query.to_sql

      # Should parameterize each value
      params.size.should eq(3)
      sql.should contain("IN")
    end

    it "prevents SQL injection in ORDER BY with validated columns" do
      schema = CQL::Schema.define(
        :security_test5,
        adapter: CQL::Adapter::SQLite,
        uri: "sqlite3::memory:"
      ) do
        table :users do
          primary :id, Int64
          text :username
          text :email
        end
      end

      schema.users.create!

      # Attempt injection via ORDER BY
      # This should fail at the column lookup stage
      expect_raises(ArgumentError) do
        schema.query
          .from(:users)
          .order("id; DROP TABLE users--")
      end
    end
  end

  describe "Insert Operations" do
    it "prevents SQL injection in INSERT values" do
      schema = CQL::Schema.define(
        :security_test6,
        adapter: CQL::Adapter::SQLite,
        uri: "sqlite3::memory:"
      ) do
        table :users do
          primary :id, Int64
          text :username
          text :email
        end
      end

      schema.users.create!

      # Attempt injection via insert values
      malicious_username = "admin'); DROP TABLE users;--"
      malicious_email = "test@example.com"

      insert = schema.insert
        .into(:users)
        .values(username: malicious_username, email: malicious_email)

      sql, params = insert.to_sql

      # Should be parameterized
      sql.should contain("?")
      params.should contain(malicious_username)
      params.should contain(malicious_email)

      # Execute and verify it's stored as literal string
      id = insert.last_insert_id(as: Int64)
      id.should be > 0

      # Verify the malicious string was stored as data
      # Query to check if the malicious string was stored safely as a literal
      result = schema.query
        .from(:users)
        .where(id: id)
        .all({id: Int64, username: String, email: String})

      result.size.should eq(1)
      result.first[:username].should eq(malicious_username)
    end
  end

  describe "Update Operations" do
    it "prevents SQL injection in UPDATE values" do
      schema = CQL::Schema.define(
        :security_test7,
        adapter: CQL::Adapter::SQLite,
        uri: "sqlite3::memory:"
      ) do
        table :users do
          primary :id, Int64
          text :username
          text :email
        end
      end

      schema.users.create!

      # Create a test user
      id = schema.insert
        .into(:users)
        .values(username: "testuser", email: "test@example.com")
        .last_insert_id(as: Int64)

      # Attempt injection via update
      malicious_username = "admin'; DROP TABLE users;--"

      update = schema.update
        .table(:users)
        .set(username: malicious_username)
        .where(id: id)

      sql, params = update.to_sql

      # Should be parameterized
      sql.should contain("?")
      params.should contain(malicious_username)

      # Execute update
      update.commit

      # Verify malicious string stored as data
      result = schema.query
        .from(:users)
        .where(id: id)
        .all({id: Int64, username: String, email: String})

      result.size.should eq(1)
      result.first[:username].should eq(malicious_username)
    end
  end

  describe "Delete Operations" do
    it "prevents SQL injection in DELETE conditions" do
      schema = CQL::Schema.define(
        :security_test8,
        adapter: CQL::Adapter::SQLite,
        uri: "sqlite3::memory:"
      ) do
        table :users do
          primary :id, Int64
          text :username
        end
      end

      schema.users.create!

      # Create test users
      schema.insert.into(:users).values(username: "user1").commit
      schema.insert.into(:users).values(username: "user2").commit

      # Attempt injection via delete condition
      malicious_username = "user1' OR '1'='1"

      delete = schema.delete
        .from(:users)
        .where(username: malicious_username)

      sql, params = delete.to_sql

      # Should be parameterized
      sql.should contain("?")
      params.should eq([malicious_username])

      # Execute - should delete nothing (no matching username)
      delete.commit

      # Verify all users still exist
      count = schema.query
        .from(:users)
        .count
        .first!(Int64)

      count.should eq(2)
    end
  end

  describe "Identifier Validation" do
    it "validates table names and prevents SQL injection" do
      expect_raises(CQL::Error) do
        CQL::Schema.define(
          :security_test9,
          adapter: CQL::Adapter::SQLite,
          uri: "sqlite3::memory:"
        ) do
          table :"users; DROP TABLE important_data;--" do
            primary :id, Int64
          end
        end
      end
    end

    it "rejects table names with spaces" do
      expect_raises(CQL::Error, /cannot contain spaces/) do
        CQL::Schema.define(
          :security_test10,
          adapter: CQL::Adapter::SQLite,
          uri: "sqlite3::memory:"
        ) do
          table :"users table" do
            primary :id, Int64
          end
        end
      end
    end

    it "rejects table names starting with numbers" do
      expect_raises(CQL::Error, /cannot start with a number/) do
        CQL::Schema.define(
          :security_test11,
          adapter: CQL::Adapter::SQLite,
          uri: "sqlite3::memory:"
        ) do
          table :"123users" do
            primary :id, Int64
          end
        end
      end
    end

    it "rejects empty table names" do
      expect_raises(CQL::Error, /cannot be empty/) do
        CQL::Schema.define(
          :security_test12,
          adapter: CQL::Adapter::SQLite,
          uri: "sqlite3::memory:"
        ) do
          table :"" do
            primary :id, Int64
          end
        end
      end
    end
  end

  describe "NULL Handling" do
    it "safely handles NULL values in WHERE clauses" do
      schema = CQL::Schema.define(
        :security_test13,
        adapter: CQL::Adapter::SQLite,
        uri: "sqlite3::memory:"
      ) do
        table :users do
          primary :id, Int64
          text :email, null: true
        end
      end

      schema.users.create!

      # Insert user with NULL email
      id = schema.insert
        .into(:users)
        .values(email: nil)
        .last_insert_id(as: Int64)

      # Query for NULL using new explicit method
      users = schema.query
        .from(:users)
        .where_null(:email)
        .all({id: Int64, email: String?})

      users.size.should eq(1)
      users.first[:id].should eq(id)
    end

    it "safely handles NOT NULL checks" do
      schema = CQL::Schema.define(
        :security_test14,
        adapter: CQL::Adapter::SQLite,
        uri: "sqlite3::memory:"
      ) do
        table :users do
          primary :id, Int64
          text :email, null: true
        end
      end

      schema.users.create!

      # Insert users with and without emails
      schema.insert.into(:users).values(email: nil).commit
      id2 = schema.insert
        .into(:users)
        .values(email: "test@example.com")
        .last_insert_id(as: Int64)

      # Query for NOT NULL using new explicit method
      users = schema.query
        .from(:users)
        .where_not_null(:email)
        .all({id: Int64, email: String?})

      users.size.should eq(1)
      users.first[:id].should eq(id2)
    end
  end
end
