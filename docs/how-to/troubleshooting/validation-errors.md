# Fix Validation Errors

This guide helps you diagnose and fix validation errors.

## Check What's Invalid

```crystal
user = User.new("", "invalid-email")

unless user.valid?
  user.errors.each do |error|
    puts "#{error.field}: #{error.message}"
  end
end
```

## Common Error: Presence Validation Failed

**Error:**
```
name: can't be blank
```

**Cause:** Field is empty or nil.

**Solutions:**

1. Provide a value:
```crystal
user = User.new("John", "john@example.com")  # Not empty
```

2. If field should be optional, adjust validation:
```crystal
# Remove presence validation or make it conditional
validate :bio, presence: true, on: :update
```

## Common Error: Format Validation Failed

**Error:**
```
email: is invalid
```

**Cause:** Value doesn't match the required format.

**Solutions:**

1. Fix the value:
```crystal
user.email = "john@example.com"  # Valid email format
```

2. Check the regex pattern:
```crystal
# Make sure pattern matches expected format
validate :email, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
```

## Common Error: Size Validation Failed

**Error:**
```
username: is too short (minimum is 3 characters)
```

**Solutions:**

1. Provide longer value:
```crystal
user.username = "john"  # At least 3 characters
```

2. Adjust size requirement if too strict:
```crystal
validate :username, size: 2..50  # Allow shorter names
```

## Common Error: Uniqueness Validation Failed

**Error:**
```
email: has already been taken
```

**Cause:** Another record has the same value.

**Solutions:**

1. Use a different value:
```crystal
user.email = "different@example.com"
```

2. Find and handle the existing record:
```crystal
existing = User.find_by(email: email)
if existing
  # Handle duplicate - update existing or reject
end
```

## Common Error: Numeric Validation Failed

**Error:**
```
age: must be greater than 0
```

**Solutions:**

1. Provide valid number:
```crystal
user.age = 25  # Positive number
```

2. Check validation constraints:
```crystal
validate :age, gt: 0, lt: 150
```

## Debugging Validation

Print all errors with details:

```crystal
user = User.new("", "bad", -5)

if user.valid?
  puts "Valid!"
else
  puts "Validation failed:"
  puts "Errors count: #{user.errors.size}"

  user.errors.each do |error|
    puts "  Field: #{error.field}"
    puts "  Message: #{error.message}"
    puts ""
  end
end
```

## Skip Validation (Use Carefully)

Sometimes you need to bypass validation:

```crystal
# Direct database update bypasses model validation
User.where(id: 1).update!(email: "override@example.com")
```

## Test Validations

```crystal
describe User do
  it "requires a name" do
    user = User.new("", "test@example.com")
    user.valid?.should be_false
    user.errors.map(&.field).should contain(:name)
  end

  it "requires valid email format" do
    user = User.new("John", "invalid")
    user.valid?.should be_false
    user.errors.map(&.field).should contain(:email)
  end

  it "accepts valid data" do
    user = User.new("John", "john@example.com")
    user.valid?.should be_true
  end
end
```

## Handle Validation in Controllers

```crystal
def create(params)
  user = User.new(params[:name], params[:email])

  if user.save
    {status: "success", user: user.to_json}
  else
    {
      status: "error",
      errors: user.errors.map { |e| {field: e.field, message: e.message} }
    }
  end
end
```

## Custom Error Messages

Make errors user-friendly:

```crystal
validate :email, required: true, message: "Please provide your email address"
validate :password, size: 8..100, message: "Password must be at least 8 characters"
```

## Related

- [Add Validations](../models/add-validations.md)
- [Validation Options Reference](../../reference/api/validation-options.md)
- [Create Records](../data-operations/create.md)
