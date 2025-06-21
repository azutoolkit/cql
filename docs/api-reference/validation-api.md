---
description: >-
  Complete API reference for CQL model validations - built-in validators, custom validation methods, validation contexts, error handling, and lifecycle.
---

# Validation API Reference

This reference documents all validation features available in CQL's Active Record implementation.

## Overview

CQL provides a comprehensive validation system that allows you to ensure data integrity at the model level. Validations are checked before records are saved to the database.

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  validates :name, presence: true, length: {minimum: 2, maximum: 100}
  validates :email, presence: true, format: /@/
  validates :age, numericality: {greater_than: 0, less_than: 120}
end
```

## Validation Declaration

### validates

````crystal
validates field : Symbol, **options

# Description
# Declares validation rules for a model field.

# Parameters
# - **field** [Symbol] The field name to validate
# - **options** [Hash] Validation options and rules

# Example
# ```crystal
# validates :email, presence: true, format: /@/
# validates :age, numericality: {greater_than: 0}
# ```
````

## Built-in Validators

### Presence Validator

````crystal
validates :field, presence: true

# Description
# Ensures the field is not nil, empty string, or whitespace-only.

# Options
# - **true** [Bool] Enable presence validation

# Example
# ```crystal
# validates :name, presence: true
# validates :email, presence: true
# ```
````

### Length Validator

````crystal
validates :field, length: {minimum: Int32?, maximum: Int32?, is: Int32?}

# Description
# Validates the length of string fields.

# Options
# - **minimum** [Int32?] Minimum length
# - **maximum** [Int32?] Maximum length
# - **is** [Int32?] Exact length

# Example
# ```crystal
# validates :name, length: {minimum: 2, maximum: 100}
# validates :password, length: {is: 8}
# validates :bio, length: {maximum: 1000}
# ```
````

### Format Validator

````crystal
validates :field, format: Regex

# Description
# Validates the field against a regular expression pattern.

# Parameters
# - **Regex** [Regex] Regular expression to match against

# Example
# ```crystal
# validates :email, format: /^[^@]+@[^@]+\.[^@]+$/
# validates :phone, format: /^\d{3}-\d{3}-\d{4}$/
# ```
````

### Numericality Validator

````crystal
validates :field, numericality: {greater_than: Number?, greater_than_or_equal_to: Number?, equal_to: Number?, less_than: Number?, less_than_or_equal_to: Number?, odd: Bool?, even: Bool?}

# Description
# Validates that the field is a number and meets specified conditions.

# Options
# - **greater_than** [Number?] Must be greater than this value
# - **greater_than_or_equal_to** [Number?] Must be greater than or equal to this value
# - **equal_to** [Number?] Must be equal to this value
# - **less_than** [Number?] Must be less than this value
# - **less_than_or_equal_to** [Number?] Must be less than or equal to this value
# - **odd** [Bool?] Must be an odd number
# - **even** [Bool?] Must be an even number

# Example
# ```crystal
# validates :age, numericality: {greater_than: 0, less_than: 120}
# validates :score, numericality: {greater_than_or_equal_to: 0, less_than_or_equal_to: 100}
# validates :quantity, numericality: {greater_than: 0, even: true}
# ```
````

### Inclusion Validator

````crystal
validates :field, inclusion: {in: Array(T), message: String?}

# Description
# Validates that the field value is included in a specified array.

# Options
# - **in** [Array(T)] Array of allowed values
# - **message** [String?] Custom error message

# Example
# ```crystal
# validates :role, inclusion: {in: ["admin", "user", "moderator"]}
# validates :status, inclusion: {in: ["active", "inactive"], message: "must be active or inactive"}
# ```
````

### Exclusion Validator

````crystal
validates :field, exclusion: {in: Array(T), message: String?}

# Description
# Validates that the field value is not included in a specified array.

# Options
# - **in** [Array(T)] Array of forbidden values
# - **message** [String?] Custom error message

# Example
# ```crystal
# validates :username, exclusion: {in: ["admin", "root", "system"]}
# validates :domain, exclusion: {in: ["localhost", "test"], message: "cannot use reserved domain"}
# ```
````

### Uniqueness Validator

````crystal
validates :field, uniqueness: {scope: Symbol | Array(Symbol)?, case_sensitive: Bool?}

# Description
# Validates that the field value is unique in the database.

# Options
# - **scope** [Symbol | Array(Symbol)?] Additional fields to scope uniqueness
# - **case_sensitive** [Bool?] Whether to perform case-sensitive comparison

# Example
# ```crystal
# validates :email, uniqueness: true
# validates :username, uniqueness: {case_sensitive: false}
# validates :title, uniqueness: {scope: :category_id}
# ```
````

### Custom Validator

````crystal
validates :field, custom: ->(value : T, record : Model) { Bool }

# Description
# Validates using a custom validation function.

# Parameters
# - **value** [T] The field value to validate
# - **record** [Model] The model instance being validated

# Returns
# [Bool] True if validation passes

# Example
# ```crystal
# validates :password, custom: ->(value : String, record : User) {
#   value.size >= 8 && value.match(/[A-Z]/) && value.match(/[0-9]/)
# }
# ```
````

## Validation Methods

### valid?

````crystal
def valid?(context = nil) : Bool

# Description
# Checks if the record is valid according to all validation rules.

# Parameters
# - **context** [Symbol?] Validation context (e.g., :create, :update)

# Returns
# [Bool] True if all validations pass

# Example
# ```crystal
# user = User.new(name: "John", email: "john@example.com")
# user.valid? # => true
#
# user = User.new(name: "", email: "invalid")
# user.valid? # => false
# ```
````

### validate!

````crystal
def validate!(context = nil) : Bool

# Description
# Validates the record and raises an exception if validation fails.

# Parameters
# - **context** [Symbol?] Validation context

# Returns
# [Bool] True if all validations pass

# Raises
# [CQL::ValidationError] When validation fails

# Example
# ```crystal
# begin
#   user.validate!
# rescue CQL::ValidationError => ex
#   puts "Validation failed: #{ex.message}"
# end
# ```
````

### errors

````crystal
def errors(context = nil) : Array(CQL::ActiveRecord::Error)

# Description
# Returns all validation errors for the record.

# Parameters
# - **context** [Symbol?] Validation context

# Returns
# [Array(CQL::ActiveRecord::Error)] Array of validation errors

# Example
# ```crystal
# user = User.new(name: "", email: "invalid")
# user.valid? # => false
# user.errors.each do |error|
#   puts "#{error.field}: #{error.message}"
# end
# ```
````

## Error Classes

### CQL::ActiveRecord::Error

````crystal
class CQL::ActiveRecord::Error
  # Description
  # Represents a single validation error.

  # Properties
  # - **field** [Symbol] The field that failed validation
  # - **message** [String] The error message
  # - **value** [DB::Any] The value that failed validation

  # Example
  # ```crystal
  # user = User.new(name: "")
  # user.valid?
  # error = user.errors.first
  # puts "#{error.field}: #{error.message}"
  # ```
end
````

### CQL::ValidationError

````crystal
class CQL::ValidationError < Exception
  # Description
  # Raised when model validation fails.

  # Properties
  # - **errors** [Array(CQL::ActiveRecord::Error)] Collection of validation errors

  # Example
  # ```crystal
  # begin
  #   user.save!
  # rescue CQL::ValidationError => ex
  #   ex.errors.each do |error|
  #     puts "#{error.field}: #{error.message}"
  #   end
  # end
  # ```
end
````

## Validation Contexts

### Context-based Validation

````crystal
validates :password, presence: true, length: {minimum: 8}, on: :create
validates :email, uniqueness: true, on: :update

# Description
# Validations can be scoped to specific contexts.

# Contexts
# - **:create** - Only run on record creation
# - **:update** - Only run on record updates
# - **:save** - Run on both create and update (default)

# Example
# ```crystal
# struct User
#   include CQL::ActiveRecord::Model(Int64)
#
#   # Password required only on creation
#   validates :password, presence: true, on: :create
#
#   # Email uniqueness checked on updates
#   validates :email, uniqueness: true, on: :update
# end
# ```
````

## Custom Validators

### Creating Custom Validators

```crystal
class CustomValidator
  def self.validate(value : T, record : Model) : Bool
    # Custom validation logic
    true
  end
end

# Usage
validates :field, custom: CustomValidator.method(:validate)
```

### Inline Custom Validators

```crystal
validates :password, custom: ->(value : String, record : User) {
  # Must contain at least one uppercase letter and one number
  value.match(/[A-Z]/) && value.match(/[0-9]/)
}
```

## Validation Lifecycle

### When Validations Run

Validations are automatically run in the following scenarios:

1. **Before Save**: All validations run before `save` or `save!`
2. **Before Create**: Context-specific validations run before record creation
3. **Before Update**: Context-specific validations run before record updates
4. **Manual Validation**: When calling `valid?` or `validate!`

### Validation Order

1. **Built-in validators** run in declaration order
2. **Custom validators** run after built-in validators
3. **Context-specific validations** run only for their specified context

## Best Practices

### Validation Organization

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  # Basic validations
  validates :name, presence: true, length: {minimum: 2, maximum: 100}
  validates :email, presence: true, format: /@/, uniqueness: true

  # Business logic validations
  validates :age, numericality: {greater_than: 0, less_than: 120}
  validates :role, inclusion: {in: ["user", "admin", "moderator"]}

  # Custom validations
  validates :password, custom: ->(value : String, record : User) {
    value.size >= 8 && value.match(/[A-Z]/) && value.match(/[0-9]/)
  }, on: :create
end
```

### Error Handling

```crystal
def create_user(user_params)
  user = User.new(user_params)

  if user.valid?
    user.save!
    {success: true, user: user}
  else
    {success: false, errors: user.errors}
  end
rescue CQL::ValidationError => ex
  {success: false, errors: ex.errors}
end
```

### Performance Considerations

```crystal
# Use specific validations instead of custom validators when possible
validates :email, format: /@/  # Better than custom validator

# Avoid expensive operations in custom validators
validates :field, custom: ->(value : String, record : User) {
  # Don't do database queries here
  # Use uniqueness validator instead
}
```

### Validation Messages

```crystal
# Custom error messages
validates :email, presence: {message: "Email address is required"}
validates :age, numericality: {
  greater_than: 0,
  message: "Age must be a positive number"
}

# Internationalization support
validates :name, presence: {message: I18n.t("errors.messages.required")}
```

## Integration with Callbacks

### Validation Callbacks

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  validates :email, presence: true

  # Callbacks can modify data before validation
  before_validation :normalize_email

  private def normalize_email
    @email = @email.downcase if @email
  end
end
```

### Conditional Validations

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  validates :password, presence: true, if: :password_required?

  private def password_required?
    new_record? || password_changed?
  end
end
```

This API reference provides comprehensive documentation for all validation functionality in CQL. Use it alongside the guides for practical examples and best practices.
