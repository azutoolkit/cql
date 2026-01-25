# Add Validations

This guide shows you how to add validations to your CQL models to ensure data integrity.

## Basic Validation Syntax

Use the `validate` macro to define validations:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property name : String
  property email : String
  property age : Int32 = 0

  validate :name, presence: true
  validate :email, required: true, match: /@/
  validate :age, gt: 0, lt: 120

  def initialize(@name : String, @email : String, @age : Int32 = 0)
  end
end
```

## Available Validators

### Presence and Required

```crystal
validate :name, presence: true      # Not nil AND not empty
validate :user_id, required: true   # Not nil (can be empty)
```

### Size

```crystal
validate :username, size: 3..20     # Between 3 and 20 characters
validate :zip_code, size: 5         # Exactly 5 characters
```

### Numeric Comparisons

```crystal
validate :age, gt: 0                # Greater than 0
validate :age, gte: 18              # Greater than or equal to 18
validate :score, lt: 100            # Less than 100
validate :score, lte: 100           # Less than or equal to 100
validate :priority, eq: 1           # Exactly 1
```

### Pattern Matching

```crystal
validate :email, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
validate :phone, match: /\A\d{3}-\d{3}-\d{4}\z/
```

### Inclusion and Exclusion

```crystal
validate :status, in: ["active", "inactive", "pending"]
validate :rating, in: 1..5
validate :username, exclude: ["admin", "root", "system"]
```

## Custom Error Messages

Add the `message` parameter:

```crystal
validate :name, presence: true, message: "Name cannot be blank"
validate :email, match: /@/, message: "Please enter a valid email address"
validate :age, gt: 0, message: "Age must be a positive number"
```

## Checking Validity

### Check if Valid

```crystal
user = User.new("", "invalid-email", -5)

if user.valid?
  puts "User is valid"
else
  puts "User has errors"
end
```

### Access Errors

```crystal
user = User.new("", "invalid-email", -5)

unless user.valid?
  user.errors.each do |error|
    puts "#{error.field}: #{error.message}"
  end
end
```

### Validate and Raise

```crystal
user = User.new("", "invalid", -5)

begin
  user.validate!
rescue ex
  puts "Validation failed: #{ex.message}"
end
```

## Custom Validators

For complex validation logic, create a custom validator:

```crystal
class PasswordValidator < CQL::ActiveRecord::Validations::CustomValidator
  def valid? : Array(CQL::ActiveRecord::Validations::Error)
    errors = [] of CQL::ActiveRecord::Validations::Error
    password = @record.password

    unless password && password.size >= 8
      errors << CQL::ActiveRecord::Validations::Error.new(:password, "must be at least 8 characters")
    end

    unless password && password.matches?(/[A-Z]/)
      errors << CQL::ActiveRecord::Validations::Error.new(:password, "must contain an uppercase letter")
    end

    unless password && password.matches?(/\d/)
      errors << CQL::ActiveRecord::Validations::Error.new(:password, "must contain a number")
    end

    errors
  end
end

struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property name : String
  property password : String?

  use PasswordValidator

  def initialize(@name : String, @password : String? = nil)
  end
end
```

## Uniqueness Validation

Check for uniqueness manually in a custom validation:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property email : String

  validate :email, presence: true

  def validate
    super
    validate_email_uniqueness
  end

  private def validate_email_uniqueness
    existing = User.find_by(email: @email)
    if existing && existing.id != @id
      errors.add(:email, "has already been taken")
    end
  end

  def initialize(@email : String)
  end
end
```

## Validations and Save

Validations run automatically when saving:

```crystal
user = User.new("", "invalid")

# save returns false if invalid
if user.save
  puts "Saved!"
else
  puts "Failed: #{user.errors.map(&.message).join(", ")}"
end

# save! raises if invalid
begin
  user.save!
rescue ex
  puts "Error: #{ex.message}"
end
```

## Verify It Works

```crystal
# Test valid data
user = User.new("John Doe", "john@example.com", 30)
user.valid?  # => true

# Test invalid data
bad_user = User.new("", "invalid", -5)
bad_user.valid?  # => false
bad_user.errors.size  # => 3
```

## Related

- [Define a Model](define-model.md)
- [Use Callbacks](use-callbacks.md)
- [Validation Options Reference](../../reference/api/validation-options.md)
