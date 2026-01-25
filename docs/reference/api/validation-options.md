# Validation Options Reference

Complete reference for all validation options available in CQL models.

## Validation Macro

```crystal
validate :field_name, option: value, option2: value2
```

## Common Options

### presence

Validates that a field is not nil and not empty.

```crystal
validate :name, presence: true
validate :email, presence: true
```

**Error:** "field_name is required"

### format / match

Validates that a field matches a regular expression.

```crystal
validate :email, match: /@/
validate :phone, match: /^\d{10}$/
validate :slug, match: /^[a-z0-9-]+$/
```

**Error:** "field_name format is invalid"

### size

Validates the length of a string or size of a collection.

```crystal
validate :password, size: 8..128          # Range
validate :username, size: 3..20
validate :tags, size: 1..5                # Array size
```

**Error:** "field_name must be between X and Y characters"

### gt / gte / lt / lte

Validates numeric values are within bounds.

```crystal
validate :age, gte: 0                # Greater than or equal to 0
validate :age, lte: 150              # Less than or equal to 150
validate :quantity, gte: 1, lte: 100 # Between 1 and 100
validate :price, gt: 0               # Greater than 0
```

**Error:** "field_name must be greater than X" / "field_name must be less than or equal to X"

### in

Validates that a value is in a list of allowed values.

```crystal
validate :status, in: ["pending", "active", "cancelled"]
validate :role, in: ["admin", "moderator", "user"]
validate :priority, in: [1, 2, 3, 4, 5]
```

**Error:** "field_name must be one of: X, Y, Z"

### exclude

Validates that a value is not in a list of excluded values.

```crystal
validate :username, exclude: ["admin", "root", "system"]
validate :status, exclude: ["deleted"]
```

**Error:** "field_name must not be included in [X, Y, Z]"

## Combining Validations

Multiple validations can be applied to a single field:

```crystal
validate :email, presence: true, match: /@/
validate :username, presence: true, size: 3..20, match: /^[a-z0-9_]+$/
validate :age, presence: true, gte: 0, lte: 150
```

## Model Example

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property email : String
  property username : String
  property password : String
  property age : Int32?
  property role : String = "user"

  # Required fields
  validate :email, presence: true
  validate :username, presence: true
  validate :password, presence: true

  # Format validations
  validate :email, match: /^[^@\s]+@[^@\s]+\.[^@\s]+$/
  validate :username, match: /^[a-z0-9_]+$/

  # Length validations
  validate :username, size: 3..20
  validate :password, size: 8..128

  # Numeric constraints
  validate :age, gte: 0, lte: 150

  # Allowed values
  validate :role, in: ["admin", "moderator", "user"]
end
```

## Checking Validation

```crystal
user = User.new("test", "test@example.com", "password123")

if user.valid?
  user.save
else
  user.errors.each do |error|
    puts error
  end
end

# Or use save! which raises on validation failure
begin
  user.save!
rescue CQL::ValidationError => e
  puts "Validation failed: #{e.message}"
end
```

## Custom Validations

For complex validations, use callbacks:

```crystal
struct Order
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property total : Float64
  property discount : Float64 = 0.0

  before_save :validate_discount

  private def validate_discount
    if @discount > @total
      errors.add(:discount, "cannot exceed total")
      return false
    end
    true
  end
end
```

## See Also

- [Add Validations](../../how-to/models/add-validations.md)
- [Fix Validation Errors](../../how-to/troubleshooting/validation-errors.md)
- [Callback Hooks Reference](callback-hooks.md)
