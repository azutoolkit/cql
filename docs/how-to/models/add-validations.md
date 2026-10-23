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

### Confirmation and Acceptance

```crystal
validate :password_confirmation, confirmation: :password   # Must equal the value of #password
validate :terms_accepted, accept: true                     # true, "true", "1", "on" or "yes"
```

`confirmation:` takes the name of another property on the model. `accept: true` treats `true`, `"true"`, `"1"`, `"on"` and `"yes"` as accepted.

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

### Unknown Options

Only these options are accepted: `eq`, `exclude`, `gt`, `gte`, `in`, `lt`, `lte`, `match`, `size`, `presence`, `required`, `confirmation`, `accept`, plus `message` and `on`. Any other option, or a `validate` for a property that does not exist, fails at compile time.

### Validation Contexts

Pass `on:` to run a rule only for a given context, then pass the context to `valid?`, `errors` or `validate!`:

```crystal
validate :password, presence: true, on: :signup

user.valid?(:signup)   # runs rules without `on:` and rules marked `on: :signup`
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

`errors` re-runs the validations on every call and returns an `Array(CQL::ActiveRecord::Validations::Error)`; there is no `errors.add`. Each error has `field` (a `Symbol`) and `message`.

### Validate and Raise

```crystal
user = User.new("", "invalid", -5)

begin
  user.validate!
rescue ex : CQL::ActiveRecord::Validations::ValidationError
  puts "Validation failed: #{ex.message}"   # messages joined with ","
end
```

## Custom Validators

For complex validation logic, subclass `CustomValidator`. It receives the record in its constructor (type it in your subclass) and returns an array of errors from `valid?`:

```crystal
class PasswordValidator < CQL::ActiveRecord::Validations::CustomValidator
  def initialize(@record : User)
  end

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

Custom validators also include the built-in predicates (`presence?`, `gt?`, `match?` and so on), so you can reuse them inside `valid?`.

## Uniqueness Validation

There is no built-in `uniqueness` option. Check it in a custom validator, and back it with a unique index in the schema:

```crystal
class UniqueEmailValidator < CQL::ActiveRecord::Validations::CustomValidator
  def initialize(@record : User)
  end

  def valid? : Array(CQL::ActiveRecord::Validations::Error)
    existing = User.find_by(email: @record.email)
    if existing && existing.id != @record.id
      [CQL::ActiveRecord::Validations::Error.new(:email, "has already been taken")]
    else
      [] of CQL::ActiveRecord::Validations::Error
    end
  end
end

struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property email : String

  validate :email, presence: true
  use UniqueEmailValidator

  def initialize(@email : String)
  end
end
```

## Validations and Save

`save`, `save!` and `create!` run validations before touching the database (`update!` does not; use `save` to update with validation). An invalid record raises `CQL::ActiveRecord::Validations::ValidationError`:

```crystal
user = User.new("", "invalid")

begin
  user.save!
rescue ex : CQL::ActiveRecord::Validations::ValidationError
  puts "Error: #{ex.message}"
end
```

To avoid exceptions, check `valid?` first:

```crystal
if user.valid?
  user.save
else
  puts "Failed: #{user.errors.map(&.message).join(", ")}"
end
```

A `before_*` callback that returns `false` makes `save` return `false` without raising. See [Use Callbacks](use-callbacks.md).

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
