require "./spec_helper"

# Test class for acceptance validation
class TestAcceptanceUser
  include CQL::ActiveRecord::Validations

  property name : String?
  property email : String?
  property terms_accepted : Bool | String | Nil

  validate :terms_accepted, accept: true, message: "Terms must be accepted"

  def initialize(@name = nil, @email = nil, @terms_accepted = nil)
  end
end

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
          user = TestUser.new("", "john@example.com", 30, "password123", "password123")
          user.valid?.should be_false
          user.errors.map(&.message).should contain("Name is invalid")
        end

        it "should be invalid when name is too short" do
          user = TestUser.new("J", "john@example.com", 30, "password123", "password123")
          user.valid?.should be_false
          user.errors.map(&.message).should contain("Name is invalid")
        end

        it "should be invalid when name is too long" do
          user = TestUser.new("J" * 51, "john@example.com", 30, "password123", "password123")
          user.valid?.should be_false
          user.errors.map(&.message).should contain("Name is invalid")
        end
      end

      describe "email validation" do
        it "should be invalid when email is empty" do
          user = TestUser.new("John Doe", "", 30, "password123", "password123")
          user.valid?.should be_false
          user.errors.map(&.message).should contain("Email format is invalid")
        end

        it "should be invalid with malformed email" do
          user = TestUser.new("John Doe", "invalid-email", 30, "password123", "password123")
          user.valid?.should be_false
          user.errors.map(&.message).should contain("Email format is invalid")
        end

        it "should be valid with proper email format" do
          user = TestUser.new("John Doe", "john.doe@example.com", 30, "password123", "password123")
          user.valid?.should be_true
          user.errors.map(&.message).should_not contain("Email format is invalid")
        end
      end

      describe "age validation" do
        it "should be invalid when age is nil" do
          user = TestUser.new("John Doe", "john@example.com", 0, "password123", "password123")
          user.valid?.should be_false
          user.errors.empty?.should be_false
        end

        it "should be invalid when age is less than 0" do
          user = TestUser.new("John Doe", "john@example.com", -1, "password123", "password123")
          user.valid?.should be_false
          user.errors.map(&.message).should contain("Age must be between a reasonable range")
        end

        it "should be invalid when age is greater than 120" do
          user = TestUser.new("John Doe", "john@example.com", 121, "password123", "password123")
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

    describe "acceptance validation" do
      it "should be valid when terms are accepted with true" do
        user = TestAcceptanceUser.new("John Doe", "john@example.com", true)
        user.valid?.should be_true
        user.errors.map(&.message).should_not contain("Terms must be accepted")
      end

      it "should be valid when terms are accepted with string 'true'" do
        user = TestAcceptanceUser.new("John Doe", "john@example.com", "true")
        user.valid?.should be_true
        user.errors.map(&.message).should_not contain("Terms must be accepted")
      end

      it "should be valid when terms are accepted with '1'" do
        user = TestAcceptanceUser.new("John Doe", "john@example.com", "1")
        user.valid?.should be_true
        user.errors.map(&.message).should_not contain("Terms must be accepted")
      end

      it "should be valid when terms are accepted with 'yes'" do
        user = TestAcceptanceUser.new("John Doe", "john@example.com", "yes")
        user.valid?.should be_true
        user.errors.map(&.message).should_not contain("Terms must be accepted")
      end

      it "should be invalid when terms are not accepted (false)" do
        user = TestAcceptanceUser.new("John Doe", "john@example.com", false)
        user.valid?.should be_false
        user.errors.map(&.message).should contain("Terms must be accepted")
      end

      it "should be invalid when terms are not accepted (nil)" do
        user = TestAcceptanceUser.new("John Doe", "john@example.com", nil)
        user.valid?.should be_false
        user.errors.map(&.message).should contain("Terms must be accepted")
      end

      it "should be invalid when terms are not accepted ('no')" do
        user = TestAcceptanceUser.new("John Doe", "john@example.com", "no")
        user.valid?.should be_false
        user.errors.map(&.message).should contain("Terms must be accepted")
      end
    end
  end
end
