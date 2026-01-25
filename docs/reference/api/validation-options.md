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

### min / max

Validates numeric values are within bounds.

```crystal
validate :age, min: 0
validate :age, max: 150
validate :quantity, min: 1, max: 100
validate :price, min: 0.01
```

**Error:** "field_name must be at least X" / "field_name must be at most X"

### in

Validates that a value is in a list of allowed values.

```crystal
validate :status, in: ["pending", "active", "cancelled"]
validate :role, in: ["admin", "moderator", "user"]
validate :priority, in: [1, 2, 3, 4, 5]
```

**Error:** "field_name must be one of: X, Y, Z"

### unique

Validates that a value is unique in the database.

```crystal
validate :email, unique: true
validate :username, unique: true
validate :slug, unique: true
```

**Note:** Performs a database query on each validation.

**Error:** "field_name has already been taken"

## Combining Validations

Multiple validations can be applied to a single field:

```crystal
validate :email, presence: true, match: /@/, unique: true
validate :username, presence: true, size: 3..20, match: /^[a-z0-9_]+$/
validate :age, presence: true, min: 0, max: 150
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

  # Uniqueness
  validate :email, unique: true
  validate :username, unique: true

  # Numeric constraints
  validate :age, min: 0, max: 150

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
