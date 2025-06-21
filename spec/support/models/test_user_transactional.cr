# Define a dummy model for testing transactions
class TestUserTransactional
  include CQL::ActiveRecord::Model(Int32)
  db_context TestDBTransactional, :test_users_transactional

  getter id : Int32?
  getter name : String
  getter email : String?

  def initialize(@name : String, @email : String? = nil, @id : Int32? = nil)
  end

  # Helper to find a record by name for assertions
  # This will raise DB::NoResultsError if no record is found because `first!` is used.
  def self.find_by_name!(name_val : String)
    record = where(name: name_val).first
    raise DB::NoResultsError.new("No TestUserTransactional found with name: #{name_val}") if record.nil?
    record
  end

  # Helper that returns nil if not found
  def self.find_by_name(name_val : String)
    where(name: name_val).first
  rescue DB::NoResultsError
    nil
  end

  def reload
    self.class.find(id.not_nil!)
  end
end
