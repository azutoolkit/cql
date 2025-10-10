require "../../spec_helper"
require "../../../src/cql"
require "../../support/schemas/example_schema"
require "../../support/models/test_user"

describe "CQL::Error Handling" do
  it "provides detailed RecordInvalid errors with field information" do
    # Test the enhanced RecordInvalid exception structure directly
    error_tuples = [
      {field: :name, message: "Name is required"},
      {field: :email, message: "Email is invalid"},
    ]

    begin
      raise CQL::RecordInvalid.new("Record invalid: validation failed", error_tuples)
      fail "Expected RecordInvalid to be raised"
    rescue ex : CQL::RecordInvalid
      # Verify enhanced exception structure
      ex.error_messages.should_not be_empty
      ex.error_messages.size.should eq(2)
      ex.error_messages.should contain("Name is required")
      ex.error_messages.should contain("Email is invalid")

      ex.error_fields.should_not be_empty
      ex.error_fields.size.should eq(2)
      ex.error_fields.should contain(:name)
      ex.error_fields.should contain(:email)

      message = ex.message
      message.should_not be_nil
      message.should contain("Record invalid") if message
    end
  end

  it "provides enhanced AttributeError with context" do
    begin
      raise CQL::AttributeError.new(
        :email,
        "invalid format",
        value: "not-an-email",
        expected_type: "String matching email pattern"
      )
      fail "Expected AttributeError to be raised"
    rescue ex : CQL::AttributeError
      ex.attribute_name.should eq(:email)
      ex.value.should_not be_nil
      ex.expected_type.should_not be_nil
      ex.expected_type.try(&.should eq("String matching email pattern"))
      message = ex.message
      message.should_not be_nil
      if message
        message.should contain("invalid format")
        message.should contain("not-an-email")
      end
    end
  end

  it "provides enhanced PersistenceError with operation context" do
    begin
      raise CQL::PersistenceError.new(
        "create",
        "Database connection failed",
        model_class: "User"
      )
      fail "Expected PersistenceError to be raised"
    rescue ex : CQL::PersistenceError
      ex.operation.should eq("create")
      ex.model_class.should eq("User")
      message = ex.message
      message.should_not be_nil
      if message
        message.should contain("create")
        message.should contain("User")
        message.should contain("Database connection failed")
      end
    end
  end

  it "provides enhanced QueryError with SQL context" do
    sql = "SELECT * FROM users WHERE id = ?"
    params = [1.as(DB::Any)]

    begin
      raise CQL::QueryError.new(
        "Syntax error",
        sql: sql,
        params: params
      )
      fail "Expected QueryError to be raised"
    rescue ex : CQL::QueryError
      ex.sql.should_not be_nil
      ex.sql.try(&.should eq(sql))
      ex.params.should_not be_nil
      ex.params.try(&.should eq(params))
      message = ex.message
      message.should_not be_nil
      if message
        message.should contain("Syntax error")
        message.should contain(sql)
      end
    end
  end

  it "provides enhanced OptimisticLockError with version information" do
    begin
      raise CQL::OptimisticLockError.new(
        model_class: "Post",
        id: 123,
        expected_version: 5,
        actual_version: 6
      )
      fail "Expected OptimisticLockError to be raised"
    rescue ex : CQL::OptimisticLockError
      ex.model_class.should eq("Post")
      ex.id.should eq(123)
      ex.expected_version.should eq(5)
      ex.actual_version.should eq(6)
      message = ex.message
      message.should_not be_nil
      if message
        message.should contain("Post#123")
        message.should contain("Expected version: 5")
        message.should contain("actual: 6")
      end
    end
  end

  it "provides enhanced TransactionError with state information" do
    begin
      raise CQL::TransactionError.new(
        "Rollback failed",
        transaction_state: "rolling_back"
      )
      fail "Expected TransactionError to be raised"
    rescue ex : CQL::TransactionError
      ex.transaction_state.should eq("rolling_back")
      message = ex.message
      message.should_not be_nil
      if message
        message.should contain("Rollback failed")
        message.should contain("rolling_back")
      end
    end
  end

  it "provides enhanced MigrationError with version and direction" do
    begin
      raise CQL::MigrationError.new(
        "Column already exists",
        migration_version: 20240101120000_i64,
        direction: "up"
      )
      fail "Expected MigrationError to be raised"
    rescue ex : CQL::MigrationError
      ex.migration_version.should eq(20240101120000_i64)
      ex.direction.should eq("up")
      message = ex.message
      message.should_not be_nil
      if message
        message.should contain("Column already exists")
        message.should contain("20240101120000")
        message.should contain("up")
      end
    end
  end

  it "provides CallbackError with callback context" do
    begin
      raise CQL::CallbackError.new(
        :encrypt_password,
        :before_save,
        "Encryption failed"
      )
      fail "Expected CallbackError to be raised"
    rescue ex : CQL::CallbackError
      ex.callback_name.should eq(:encrypt_password)
      ex.callback_type.should eq(:before_save)
      message = ex.message
      message.should_not be_nil
      if message
        message.should contain("encrypt_password")
        message.should contain("before_save")
        message.should contain("Encryption failed")
      end
    end
  end
end
