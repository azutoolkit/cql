# Validation Options Reference

Complete reference for all validation options available in CQL models.

## Validation Macro

```crystal
validate :field_name, option: value, option2: value2
```

## Supported Options

`eq`, `exclude`, `gt`, `gte`, `in`, `lt`, `lte`, `match`, `size`, `presence`, `required`, `confirmation`, `accept`, plus `message` (and an `on` context option that the macro accepts but that no spec exercises, so do not rely on it). Any other option is a compile-time error that lists the supported ones. There are no `format`, `uniqueness`, `length`, `numericality` or `inclusion` options. A `validate` on a property the model does not define is also a compile-time error.

When a rule fails, CQL adds an error with the default message below, or your `message:` if you gave one. The default messages are what `errors.map(&.message)` returns.

### presence

Validates that a field is not nil and not empty.

```crystal
validate :name, presence: true
validate :email, presence: true
```

**Error:** "field_name must be present"

### required

Validates that a field is not nil (an empty string passes).

```crystal
validate :user_id, required: true
```

**Error:** "field_name is required"

### match

Validates that a string field matches a regular expression.

```crystal
validate :email, match: /@/
validate :phone, match: /^\d{10}$/
validate :slug, match: /^[a-z0-9-]+$/
```

The property must be a non-nilable `String`; `match` has no overload for `String?`.

**Error:** "field_name must match the pattern /regex/"

### size

Validates the length of a string or the size of a collection. An integer means exactly that size, a range means between.

```crystal
validate :zip_code, size: 5               # Exactly 5
validate :password, size: 8..128          # Range
validate :username, size: 3..20
validate :tags, size: 1..5                # Array size
```

**Error:** "field_name must have a size of X"

### gt / gte / lt / lte

Validates numeric values are within bounds.

```crystal
validate :age, gte: 0                # Greater than or equal to 0
validate :age, lte: 150              # Less than or equal to 150
validate :quantity, gte: 1, lte: 100 # Between 1 and 100
validate :price, gt: 0               # Greater than 0
```

The same comparisons work on `Time` values. `eq` checks equality.

```crystal
validate :priority, eq: 1
```

**Error:** "field_name must be greater than X", "field_name must be greater than or equal to X", "field_name must be less than X", "field_name must be less than or equal to X", "field_name must be equal to X"

### in

Validates that a value is in a list of allowed values.

```crystal
validate :status, in: ["pending", "active", "cancelled"]
validate :role, in: ["admin", "moderator", "user"]
validate :priority, in: [1, 2, 3, 4, 5]
```

Ranges work too: `validate :rating, in: 1..5`.

**Error:** "field_name must be included in X"

### exclude

Validates that a value is not in a list of excluded values.

```crystal
validate :username, exclude: ["admin", "root", "system"]
validate :status, exclude: ["deleted"]
```

**Error:** "field_name must not be included in X"

### confirmation

Validates that a field equals another property, such as a password and its confirmation. The value is the name of the other property.

```crystal
validate :password_confirmation, confirmation: :password
```

**Error:** "field_name confirmation doesn't match"

### accept

Validates that a field holds an accepted value: `true`, `"true"`, `"1"`, `"on"` or `"yes"`.

```crystal
validate :terms_accepted, accept: true
```

**Error:** "field_name must be accepted"

### message

Overrides the default error message for every rule in that `validate` call.

```crystal
validate :age, gt: 0, message: "Age must be a positive number"
```

## Combining Validations

Multiple rules can be applied to a single field in one `validate` call. Use one call per field: the validations are stored per property, so a second `validate :email, ...` replaces the first one instead of adding to it.

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

  # One validate call per property: a second call for the same property
  # replaces the first, so combine all rules for a property in one call.
  validate :email, presence: true, match: /^[^@\s]+@[^@\s]+\.[^@\s]+$/
  validate :username, presence: true, size: 3..20, match: /^[a-z0-9_]+$/
  validate :password, presence: true, size: 8..128

  # Numeric constraints
  validate :age, gte: 0, lte: 150

  # Allowed values
  validate :role, in: ["admin", "moderator", "user"]

  def initialize(@email : String, @username : String, @password : String)
  end
end
```

## Checking Validation

```crystal
user = User.new("test@example.com", "test", "password123")

if user.valid?
  user.save
else
  user.errors.each do |error|
    puts "#{error.field}: #{error.message}"
  end
end

# validate! raises when invalid
begin
  user.validate!
rescue e : CQL::ActiveRecord::Validations::ValidationError
  puts "Validation failed: #{e.message}"
end
```

`save`, `save!` and `create!` run the same validations and raise `CQL::ActiveRecord::Validations::ValidationError` for an invalid record. `errors` returns an `Array(CQL::ActiveRecord::Validations::Error)` rebuilt on each call (each error has `field` and `message`).

## Custom Validations

For complex validations, subclass `CQL::ActiveRecord::Validations::CustomValidator` and register it with `use`:

```crystal
class DiscountValidator < CQL::ActiveRecord::Validations::CustomValidator
  def initialize(@record : Order)
  end

  def valid? : Array(CQL::ActiveRecord::Validations::Error)
    if @record.discount > @record.total
      [CQL::ActiveRecord::Validations::Error.new(:discount, "cannot exceed total")]
    else
      [] of CQL::ActiveRecord::Validations::Error
    end
  end
end

struct Order
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :orders

  property id : Int64?
  property total : Float64
  property discount : Float64 = 0.0

  use DiscountValidator

  def initialize(@total : Float64, @discount : Float64 = 0.0)
  end
end
```

A `before_save` callback that returns `false` can also stop a save, but it does not produce validation errors.

## See Also

- [Add Validations](../../how-to/models/add-validations.md)
- [Fix Validation Errors](../../how-to/troubleshooting/validation-errors.md)
- [Callback Hooks Reference](callback-hooks.md)
