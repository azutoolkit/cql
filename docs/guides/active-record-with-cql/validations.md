# Validations

CQL's Active Record integration provides a simple yet effective way to ensure data integrity through model-level validations. By defining validation logic within your models, you can prevent invalid data from being persisted to the database.

The `CQL::ActiveRecord::Validations` module is automatically included when you use `CQL::ActiveRecord::Model(Pk)`.

---

## Defining Validations

Validations are typically implemented by overriding the `validate` instance method in your model. This method is called automatically before saving a record (create or update).

Inside the `validate` method, you should check the model's attributes. If an attribute is invalid, you add a message to the `errors` collection for that attribute.

**Model Example:**

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context AcmeDB, :users

  property id : Int64?
  property name : String
  property email : String
  property age : Int32?

  def initialize(@name : String, @email : String, @age : Int32? = nil)
  end

  # Override the validate method to add custom validation logic
  def validate
    super # It's good practice to call super in case parent classes have validations

    if name.empty?
      errors.add(:name, "cannot be blank")
    end

    if email.empty?
      errors.add(:email, "cannot be blank")
    elsif !email.includes?('@')
      errors.add(:email, "is not a valid email format")
    end

    if age_val = age
      if age_val < 18
        errors.add(:age, "must be 18 or older")
      end
    end
  end
end
```

---

## Checking Validity

You can explicitly check if a model instance is valid using the `valid?` and `validate!` methods.

### `valid?`

The `valid?` method runs the `validate` method and returns `true` if the `errors` collection is empty, and `false` otherwise. It does not raise an exception.

```crystal
user = User.new(name: "", email: "test")
user.valid? # => false
puts user.errors.full_messages.join(", ") # => "Name cannot be blank, Email is not a valid email format"

valid_user = User.new(name: "Jane Doe", email: "jane@example.com", age: 30)
valid_user.valid? # => true
puts valid_user.errors.empty? # => true
```

### `validate!`

The `validate!` method also runs the `validate` method. If the record is invalid, it raises a `CQL::Errors::RecordInvalid` exception containing the validation errors. If the record is valid, it returns `true`.

```crystal
user = User.new(name: "", email: "test")
begin
  user.validate!
rescue ex : CQL::Errors::RecordInvalid
  puts ex.message # Displays the summary of errors
  puts ex.record.errors.full_messages.join(", ") # => "Name cannot be blank, Email is not a valid email format"
end

valid_user = User.new(name: "John Doe", email: "john@example.com", age: 25)
valid_user.validate! # => true (no exception raised)
```

---

## The `errors` Object

The `errors` object is an instance of `CQL::Errors::Collection`. It provides methods to add and inspect error messages.

- **`errors.add(attribute : Symbol, message : String)`**: Adds an error message for the specified attribute.
- **`errors.empty?`**: Returns `true` if there are no errors.
- **`errors.clear`**: Removes all error messages.
- **`errors.on(attribute : Symbol)`**: Returns an array of error messages for a specific attribute, or `nil` if none.
- **`errors.full_messages`**: Returns an array of user-friendly error messages, typically in the format "Attribute_name message" (e.g., "Name cannot be blank").
- **`errors.to_h`**: Returns a hash where keys are attribute names (Symbols) and values are arrays of error messages for that attribute.

```crystal
user = User.new(name: "", email: "bademail", age: 10)
user.valid? # Run validations to populate errors

puts user.errors.on(:name)        # => ["cannot be blank"]
puts user.errors.on(:email)       # => ["is not a valid email format"]
puts user.errors.on(:age)         # => ["must be 18 or older"]
puts user.errors.on(:non_existent) # => nil

puts user.errors.full_messages
# [
#   "Name cannot be blank",
#   "Email is not a valid email format",
#   "Age must be 18 or older"
# ]

pp user.errors.to_h
# {
#   name: ["cannot be blank"],
#   email: ["is not a valid email format"],
#   age: ["must be 18 or older"]
# }
```

---

## Validations and Persistence Methods

Validation is automatically integrated with the persistence methods:

- **`save` / `save!`**:

  - `save` runs validations. If they fail (`valid?` returns `false`), `save` returns `false` and the record is not persisted.
  - `save!` also runs validations. If they fail, it raises `CQL::Errors::RecordInvalid`.

- **`create` / `create!`**:

  - `create(attributes)` is like `new(attributes).save`. It returns the instance (which may be invalid and not persisted) or `false` if using a `before_create` callback that halts.
  - `create!(attributes)` is like `new(attributes).save!`. It raises `CQL::Errors::RecordInvalid` if validations fail.

- **`update(attributes)` / `update!(attributes)`**:
  - `update` assigns attributes and then calls `save`. Returns `true` or `false`.
  - `update!` assigns attributes and then calls `save!`. Raises `CQL::Errors::RecordInvalid` on failure.

**Example with `save`:**

```crystal
invalid_user = User.new(name: "", email: "test")
if invalid_user.save
  puts "User saved successfully!" # This won't be printed
else
  puts "Failed to save user."
  puts invalid_user.errors.full_messages.join(", ")
  # => Failed to save user.
  # => Name cannot be blank, Email is not a valid email format
end

valid_user = User.new(name: "Alice", email: "alice@example.com", age: 30)
if valid_user.save
  puts "User '#{valid_user.name}' saved successfully! ID: #{valid_user.id.not_nil!}"
else
  puts "Failed to save valid user." # This won't be printed
end
```

**Example with `create!`:**

```crystal
begin
  User.create!(name: "", email: "invalid")
rescue ex : CQL::Errors::RecordInvalid
  puts "Caught error on create!: #{ex.message}"
end

new_user = User.create!(name: "Bob", email: "bob@example.com", age: 40)
puts "User '#{new_user.name}' created successfully! ID: #{new_user.id.not_nil!}"
```

---

## Custom Validation Helpers (Optional)

For more complex or reusable validation logic, you can define private helper methods within your model.

```crystal
struct Product
  include CQL::ActiveRecord::Model(Int64)
  db_context AcmeDB, :products

  property id : Int64?
  property name : String
  property price : Float64
  property sku : String

  def initialize(@name : String, @price : Float64, @sku : String)
  end

  def validate
    super
    validate_name
    validate_price
    validate_sku_format
  end

  private def validate_name
    errors.add(:name, "cannot be empty") if name.empty?
  end

  private def validate_price
    errors.add(:price, "must be positive") if price <= 0
  end

  # Example: SKU must be in format ABC-12345
  private def validate_sku_format
    unless sku.matches?(/^[A-Z]{3}-\d{5}$/)
      errors.add(:sku, "format is invalid (expected ABC-12345)")
    end
  end
end

# Example usage:
product = Product.new(name: "Test Product", price: -10.0, sku: "XYZ-123")
product.valid? # => false
pp product.errors.to_h
# {
#   price: ["must be positive"],
#   sku: ["format is invalid (expected ABC-12345)"]
# }
```

By using these validation features, you can maintain data consistency and provide clear feedback about data entry issues.
Remember that `CQL::ActiveRecord::Validations` provides a basic framework. For very complex validation scenarios or integrating with external validation libraries, you might need to extend this functionality further.
