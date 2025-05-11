require "../../spec_helper.cr"

describe "CQL::ActiveRecord::Transactional" do
  # Ensure DB setup runs once before these describe blocks
  TestDBTransactional.build

  # Clean up table before each test to ensure isolation
  before_each do
    TestUserTransactional.schema.exec("DELETE FROM test_users_transactional")
  end

  describe ".transaction" do
    it "commits operations if the block executes successfully" do
      TestUserTransactional.transaction do |_|
        TestUserTransactional.create!(name: "Alice Transactional")
        TestUserTransactional.create!(name: "Bob Transactional")
      end

      TestUserTransactional.find_by_name("Alice Transactional").should_not be_nil
      TestUserTransactional.find_by_name("Bob Transactional").should_not be_nil
      TestUserTransactional.count.should eq(2)
    end

    it "rolls back operations without raising an exception" do
      TestUserTransactional.transaction do |_|
        TestUserTransactional.create!(name: "Charlie Transactional")
        raise DB::Rollback.new("Intentional rollback")
        TestUserTransactional.create!(name: "David Transactional") # This should not be created
      end

      expect_raises(DB::NoResultsError) do
        TestUserTransactional.find_by_name!("Charlie Transactional")
      end

      TestUserTransactional.find_by_name("David Transactional").should be_nil

      TestUserTransactional.count.should eq(0)
    end

    context "ehen using nested transactions" do
      it "commits all operations with tx2.commit" do
        TestUserTransactional.transaction do |tx|
          TestUserTransactional.create!(name: "Eve Transactional")
          TestUserTransactional.transaction(tx) do |_|
            TestUserTransactional.create!(name: "Frank Transactional")
          end
        end

        TestUserTransactional.find_by_name("Eve Transactional").should_not be_nil
        TestUserTransactional.find_by_name("Frank Transactional").should_not be_nil
      end

      it "rolls back all operations with tx2.rollback" do
        TestUserTransactional.transaction do |tx|
          TestUserTransactional.create!(name: "Eve Transactional")

          TestUserTransactional.transaction(tx) do |_|
            TestUserTransactional.create!(name: "Frank Transactional") # This should not be created
            raise DB::Rollback.new("Intentional rollback")
          end
        end

        TestUserTransactional.find_by_name("Eve Transactional").should_not be_nil
        TestUserTransactional.find_by_name("Frank Transactional").should be_nil
      end

      it "rolls back only the tx2 operations with tx2.rollback" do
        TestUserTransactional.transaction do |tx|
          # First transaction
          TestUserTransactional.create!(name: "Eve Transactional") # This should be created

          TestUserTransactional.transaction(tx) do |inner_tx|
            # Second transaction
            TestUserTransactional.create!(name: "Frank Transactional") # This should not be created
            inner_tx.rollback
          end
        end

        TestUserTransactional.find_by_name("Eve Transactional").should_not be_nil
        TestUserTransactional.find_by_name("Frank Transactional").should be_nil
      end

      it "rolls back all operations with tx2.rollback" do
        begin
          TestUserTransactional.transaction do |tx|
            TestUserTransactional.create!(name: "Eve Transactional")
            TestUserTransactional.transaction(tx) do |_|
              TestUserTransactional.create!(name: "Frank Transactional")
              raise "Intentional rollback"
            end
          end
        rescue exception
        end

        TestUserTransactional.find_by_name("Eve Transactional").should be_nil
        TestUserTransactional.find_by_name("Frank Transactional").should be_nil
      end
    end

    it "rolls back operations if DB::Rollback is raised" do
      TestUserTransactional.transaction do |_|
        TestUserTransactional.create!(name: "Eve Transactional")
        raise DB::Rollback.new("Intentional rollback")
        TestUserTransactional.create!(name: "Frank Transactional") # This should not be created
      end

      expect_raises(DB::NoResultsError) do
        TestUserTransactional.find_by_name!("Eve Transactional")
      end

      expect_raises(DB::NoResultsError) do
        TestUserTransactional.find_by_name!("Frank Transactional")
      end

      TestUserTransactional.count.should eq(0)
    end

    it "allows yielding the transaction object" do
      did_yield_tx = false
      TestUserTransactional.transaction do |_|
        TestUserTransactional.create!(name: "Yielding Tx User")
        did_yield_tx = true
      end
      did_yield_tx.should be_true
      TestUserTransactional.find_by_name("Yielding Tx User").should_not be_nil
    end

    it "works when the block doesn't take the transaction object" do
      TestUserTransactional.transaction do
        TestUserTransactional.create!(name: "No Tx Arg User")
      end

      TestUserTransactional.find_by_name("No Tx Arg User").should_not be_nil
    end

    it "correctly uses schema's transaction so exec calls are part of it" do
      TestUserTransactional.transaction do |_|
        user = TestUserTransactional.create!(name: "Schema Level Test")
        # Use schema.exec directly, should be part of the same transaction
        TestUserTransactional.schema.exec("UPDATE test_users_transactional SET email = 'test@example.com' WHERE id = #{user.id.not_nil!}")
        # If we were to raise DB::Rollback here, the email update should also be rolled back.
      end

      reloaded_user = TestUserTransactional.find_by_name("Schema Level Test")
      reloaded_user.should_not be_nil
      reloaded_user.not_nil!.email.should eq("test@example.com")

      # Now test rollback part for schema.exec
      TestUserTransactional.transaction do |_|
        user = TestUserTransactional.create!(name: "Schema Rollback Test")
        TestUserTransactional.schema.exec("UPDATE test_users_transactional SET email = 'rollback@example.com' WHERE id = #{user.id.not_nil!}")
        raise DB::Rollback.new("Intentional rollback") # This will be caught by Schema#transaction silently
      end

      # Verify rollback by trying to find the user, expecting it not to exist
      expect_raises(DB::NoResultsError) do
        TestUserTransactional.find_by_name!("Schema Rollback Test")
      end
    end
  end
end
