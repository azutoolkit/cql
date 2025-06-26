# Validations in CQL Active Record

CQL provides a comprehensive validation system that ensures data integrity before records are saved to the database. The validation system is built on a predicate-based approach that leverages Crystal's type system for compile-time safety.

---

## Basic Validation Syntax

Define validations using the `validate` macro with field names and validation predicates:

```crystal
class User
  include CQL::ActiveRecord::Model(Int32)
  db_context UserDB, :users

  property id : Int32?
  property name : String
  property email : String
  property age : Int32 = 0
  property password : String?
  @[DB::Field(ignore: true)]
  property password_confirmation : String?

  # Define validations with predicates and custom messages
  validate :name, presence: true, size: 2..50, message: "Name is invalid"
  validate :email, required: true, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i, message: "Email format is invalid"
  validate :age, gt: 0, lt: 120, message: "Age must be between a reasonable range"
  validate :password_confirmation, presence: true, message: "Password confirmation is required"

  def initialize(@name : String, @email : String, @age : Int32 = 0, @password : String? = nil, @password_confirmation : String? = nil)
  end
end
```

---

## Available Validation Predicates

CQL provides a rich set of built-in validation predicates:

### Presence and Required

- **`presence: true`**: Ensures the field is not nil and not empty
- **`required: true`**: Ensures the field is not nil

```crystal
validate :name, presence: true      # Must not be nil or empty
validate :user_id, required: true   # Must not be nil (but can be empty)
```

### Numeric Comparisons

- **`gt: value`**: Greater than
- **`gte: value`**: Greater than or equal to
- **`lt: value`**: Less than
- **`lte: value`**: Less than or equal to
- **`eq: value`**: Equal to

```crystal
validate :age, gt: 0, lt: 150                    # Age between 1 and 149
validate :score, gte: 0, lte: 100               # Score between 0 and 100
validate :priority, eq: 1                       # Exact value match
```

### Size Validations

- **`size: number`**: Exact size
- **`size: range`**: Size within range

```crystal
validate :username, size: 3..20                 # Between 3 and 20 characters
validate :zip_code, size: 5                     # Exactly 5 characters
```

### Pattern Matching

- **`match: regex`**: Must match regular expression

```crystal
validate :email, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
validate :phone, match: /\A\d{3}-\d{3}-\d{4}\z/
```

### Inclusion and Exclusion

- **`in: array`**: Value must be in the array
- **`in: range`**: Value must be in the range
- **`exclude: array`**: Value must not be in the array
- **`exclude: range`**: Value must not be in the range

```crystal
validate :status, in: ["active", "inactive", "pending"]
validate :rating, in: 1..5
validate :username, exclude: ["admin", "root", "system"]
```

---

## Custom Messages

Provide custom error messages for better user experience:

```crystal
class Product
  include CQL::ActiveRecord::Model(Int32)
  db_context StoreDB, :products

  property id : Int32?
  property name : String
  property price : Float64
  property category : String

  validate :name, presence: true, message: "Product name cannot be blank"
  validate :price, gt: 0, message: "Price must be greater than zero"
  validate :category, in: ["electronics", "books", "clothing"], message: "Invalid product category"

  def initialize(@name : String, @price : Float64, @category : String)
  end
end
```

---

## Working with Validation Errors

### Checking if a Record is Valid

```crystal
user = User.new("", "invalid-email", -5)

# Check validity
if user.valid?
  puts "User is valid"
else
  puts "User has validation errors"
end
```

### Accessing Validation Errors

```crystal
user = User.new("", "invalid-email", -5)

unless user.valid?
  errors = user.errors

  # Get all error messages
  error_messages = errors.map(&.message)
  puts error_messages
  # => ["Name is invalid", "Email format is invalid", "Age must be between a reasonable range"]

  # Access individual errors
  errors.each do |error|
    puts "Field: #{error.field}, Message: #{error.message}"
  end
end
```

### Validating with Context

You can validate with specific contexts for different scenarios:

```crystal
class User
  include CQL::ActiveRecord::Model(Int32)

  # Validations can be context-specific
  validate :password, presence: true, on: :create
  validate :current_password, presence: true, on: :update
end

user = User.new("John", "john@example.com")

# Validate for specific context
user.valid?(:create)    # Checks password presence
user.valid?(:update)    # Checks current_password presence
user.valid?             # Runs all validations regardless of context
```

### Validation Exceptions

Force validation and raise an exception if invalid:

```crystal
user = User.new("", "invalid-email", -5)

begin
  user.validate!  # Raises ValidationError if invalid
rescue CQL::ActiveRecord::Validations::ValidationError => e
  puts "Validation failed: #{e.message}"
  # Message contains comma-separated error messages
end
```

---

## Custom Validators

Create custom validators for complex validation logic:

```crystal
class PasswordValidator < CQL::ActiveRecord::Validations::CustomValidator
  def valid? : Array(CQL::ActiveRecord::Validations::Error)
    errors = [] of CQL::ActiveRecord::Validations::Error

    password = @record.password

    # Check minimum length
    unless password && password.size >= 8
      errors << CQL::ActiveRecord::Validations::Error.new(:password, "Password must be at least 8 characters")
    end

    # Check for mixed case
    unless password && password.matches?(/[a-z]/) && password.matches?(/[A-Z]/)
      errors << CQL::ActiveRecord::Validations::Error.new(:password, "Password must contain both uppercase and lowercase letters")
    end

    # Check for numbers
    unless password && password.matches?(/\d/)
      errors << CQL::ActiveRecord::Validations::Error.new(:password, "Password must contain at least one number")
    end

    errors
  end
end

class User
  include CQL::ActiveRecord::Model(Int32)
  db_context UserDB, :users

  property id : Int32?
  property name : String
  property email : String
  property password : String?

  # Use custom validator
  use PasswordValidator

  validate :name, presence: true, size: 2..50, message: "Name must be between 2 and 50 characters"

  def initialize(@name : String, @email : String, @password : String? = nil)
  end
end
```

---

## Validation Best Practices

### 1. Use Appropriate Predicates

```crystal
# Good - specific predicates
validate :age, gt: 0, lt: 120
validate :email, required: true, match: EMAIL_REGEX

# Avoid - overly complex custom validators for simple cases
validate :age, custom: :validate_age_range
```

### 2. Provide Clear Error Messages

```crystal
# Good - descriptive messages
validate :email, required: true, message: "Email address is required for account creation"

# Avoid - generic messages
validate :email, required: true, message: "Invalid"
```

### 3. Use Context-Specific Validations

```crystal
class User
  # Validations that only apply during creation
  validate :password, presence: true, on: :create

  # Validations that only apply during updates
  validate :current_password, presence: true, on: :update

  # Validations that always apply
  validate :email, required: true, match: EMAIL_REGEX
end
```

### 4. Test Validations Thoroughly

```crystal
describe User do
  it "validates required fields" do
    user = User.new("", "", nil)
    user.valid?.should be_false
    user.errors.map(&.field).should contain(:name)
    user.errors.map(&.field).should contain(:email)
  end

  it "validates email format" do
    user = User.new("John", "invalid-email", "password")
    user.valid?.should be_false
    user.errors.map(&.message).should contain("Email format is invalid")
  end

  it "allows valid data" do
    user = User.new("John Doe", "john@example.com", "password123")
    user.valid?.should be_true
  end
end
```

---

## Related Features

- [Active Record Models](./defining-models.md) - How to define models with validations
- [Callbacks](./callbacks.md) - Lifecycle hooks that work with validations
- [CRUD Operations](./crud-operations.md) - How validations integrate with save operations
- [Error Handling](./error-handling.md) - Working with validation errors
