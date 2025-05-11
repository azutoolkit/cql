require "./spec_helper"

describe CQL::ActiveRecord::Validations do
  describe TestUser do
    describe "validations" do
      it "should be valid with correct attributes" do
        user = TestUser.new("John Doe", "john@example.com", 30, "password123", "password123")
        user.valid?.should be_true
        user.errors.empty?.should be_true
      end

      describe "name validation" do
        it "should be invalid when name is empty" do
          user = TestUser.new("", "john@example.com", 30)
          user.valid?.should be_false
          user.errors.map(&.message).should contain("Name is invalid")
        end

        it "should be invalid when name is too short" do
          user = TestUser.new("J", "john@example.com", 30)
          user.valid?.should be_false
          user.errors.map(&.message).should contain("Name is invalid")
        end

        it "should be invalid when name is too long" do
          user = TestUser.new("J" * 51, "john@example.com", 30)
          user.valid?.should be_false
          user.errors.map(&.message).should contain("Name is invalid")
        end
      end

      describe "email validation" do
        it "should be invalid when email is empty" do
          user = TestUser.new("John Doe", "", 30)
          user.valid?.should be_false
          user.errors.map(&.message).should contain("Email format is invalid")
        end

        it "should be invalid with malformed email" do
          user = TestUser.new("John Doe", "invalid-email", 30)
          user.valid?.should be_false
          user.errors.map(&.message).should contain("Email format is invalid")
        end

        it "should be valid with proper email format" do
          user = TestUser.new("John Doe", "john.doe@example.com", 30)
          user.valid?.should be_false
          user.errors.should_not contain("Email format is invalid")
        end
      end

      describe "age validation" do
        it "should be invalid when age is nil" do
          user = TestUser.new("John Doe", "john@example.com")
          user.valid?.should be_false
          user.errors.empty?.should be_false
        end

        it "should be invalid when age is less than 0" do
          user = TestUser.new("John Doe", "john@example.com", -1)
          user.valid?.should be_false
          user.errors.map(&.message).should contain("Age must be between a reasonable range")
        end

        it "should be invalid when age is greater than 120" do
          user = TestUser.new("John Doe", "john@example.com", 121)
          user.valid?.should be_false
          user.errors.map(&.message).should contain("Age must be between a reasonable range")
        end
      end

      describe "password confirmation validation" do
        it "should be invalid when password confirmation is empty" do
          user = TestUser.new("John Doe", "john@example.com", 30, "password123", "")
          user.valid?.should be_false
          user.errors.map(&.message).should contain("Password confirmation is required")
        end

        it "should be invalid when passwords don't match" do
          user = TestUser.new("John Doe", "john@example.com", 30, "password123", "different")
          user.valid?.should be_false
          user.errors.map(&.message).should contain("doesn't match Password")
        end

        it "should be valid when passwords match" do
          user = TestUser.new("John Doe", "john@example.com", 30, "password123", "password123")
          user.valid?.should be_true
          user.errors.empty?.should be_true
        end
      end
    end
  end
end
