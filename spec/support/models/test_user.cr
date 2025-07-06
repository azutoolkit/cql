# Create a test model for testing validations and callbacks
class TestUser
  include CQL::ActiveRecord::Model(Int32)

  db_context schema: UserDB, table: :users

  property name : String?
  property email : String
  property age : Int32 = 0
  property password : String? = nil
  property created_at : Time?
  property updated_at : Time?
  @[DB::Field(ignore: true)]
  property password_confirmation : String? = nil
  @[DB::Field(ignore: true)]
  property halt_on_callback : String? = nil

  use PasswordValidator

  # Define validations using the predicate-based approach
  validate :name, presence: true, size: 2..50, message: "Name is invalid"
  validate :email, required: true, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i, message: "Email format is invalid"
  validate :age, gt: 1, lt: 120, message: "Age must be between a reasonable range"
  validate :password_confirmation, presence: true, message: "Password confirmation is required"
  validate :password_confirmation, confirmation: :password, message: "doesn't match Password"

  # Define callbacks
  before_validation :do_before_validation
  after_validation :do_after_validation
  before_save :do_before_save
  before_save :check_halt_save
  after_save :do_after_save
  before_create :do_before_create
  after_create :do_after_create
  before_update :do_before_update
  after_update :do_after_update
  before_destroy :do_before_destroy
  before_destroy :check_halt_destroy
  after_destroy :do_after_destroy

  has_one :profile, UserProfile
  has_many :posts, Post, foreign_key: :user_id, dependent: :destroy

  def initialize(@name, @email, @age = 0, @password = nil, @password_confirmation = nil)
  end

  # Callback implementations
  def do_before_validation
    CallbackTracker.add("before_validation")
    true
  end

  def do_after_validation
    CallbackTracker.add("after_validation")
    true
  end

  def do_before_save
    CallbackTracker.add("before_save")
    true
  end

  def check_halt_save
    CallbackTracker.add("check_halt_save")
    return false if @halt_on_callback == "before_save"
    true
  end

  def do_after_save
    CallbackTracker.add("after_save")
    true
  end

  def do_before_create
    CallbackTracker.add("before_create")
    return false if @halt_on_callback == "before_create"
    true
  end

  def do_after_create
    CallbackTracker.add("after_create")
    true
  end

  def do_before_update
    CallbackTracker.add("before_update")
    return false if @halt_on_callback == "before_update"
    true
  end

  def do_after_update
    CallbackTracker.add("after_update")
    true
  end

  def do_before_destroy
    CallbackTracker.add("before_destroy")
    return false if @halt_on_callback == "before_destroy"
    true
  end

  def check_halt_destroy
    CallbackTracker.add("check_halt_destroy")
    return false if @halt_on_callback == "check_halt_destroy"
    true
  end

  def do_after_destroy
    CallbackTracker.add("after_destroy")
    true
  end
end
