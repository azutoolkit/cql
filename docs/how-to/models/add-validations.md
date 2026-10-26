---
description: "Declare rules with validate so CQL checks a record before it saves it."
---

# Add Validations

## Declare Rules

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)

  property name : String = ""
  property email : String = ""
  property age : Int32 = 30
  property password : String?

  validate :name, presence: true
  validate :email, required: true, match: /@/
  validate :age, gt: 0, lt: 120, message: "Age must be between 1 and 119"

  def initialize
  end

  def initialize(@name : String, @email : String, @age : Int32 = 30)
  end
end
```

Every option (`presence`, `required`, `match`, `size`, `gt`, `in`, `confirmation`, `accept` and the rest), the value it takes and the message it adds are listed in the [Validation Options Reference](../../reference/api/validation-options.md); `message:` replaces the message. Any other option, or a property the model does not define, fails at compile time.

Several `validate` calls on one property all apply. `on:` limits a call's rules to one kind of save:

```crystal
validate :password, presence: true, on: :create # only when save inserts the record
validate :name, size: 2..50, on: :update        # only when save updates it
```

`save`, `valid?` and `errors` check a new record as `:create` and a saved one as `:update`; pass a context to choose (`user.valid?(:update)`).

## Check a Record

```crystal
user = User.new("", "invalid", -5)

user.valid?                   # => false
user.errors.map(&.message)    # => ["name must be present", "email must match the pattern /@/",
                              #     "Age must be between 1 and 119"]
user.errors.first.field       # => :name

begin
  user.validate!
rescue ex : CQL::ActiveRecord::Validations::ValidationError
  ex.message                  # => "name must be present,email must match the pattern /@/,Age must be between 1 and 119"
end
```

`errors` runs the rules again on every call and returns an `Array(CQL::ActiveRecord::Validations::Error)`, each with a `field` (`Symbol`) and a `message`. There is no `errors.add`.

## Save With Validation

```crystal
user = User.new("", "invalid")

# ❌ save validates first and raises on an invalid record
user.save                     # raises CQL::ActiveRecord::Validations::ValidationError

# ✅ Check first when invalid input is expected
if user.valid?
  user.save
else
  puts user.errors.map(&.message).join(", ")
end

User.new("Ada", "ada@example.com").create! # validates, then INSERT
User.create!(name: "", email: "x")         # no validation: INSERT as given
```

`save`, `save!` and the instance `create!` validate. The class method `User.create!(...)` and `update!` do not, so use `save` to update with validation. A `before_*` callback that returns `false` makes `save` return `false` without raising (see [Use Callbacks](use-callbacks.md)).

## Write a Custom Validator

Subclass `CustomValidator`, type the record in `initialize`, return errors from `valid?`, and register it with `use`:

```crystal
alias Error = CQL::ActiveRecord::Validations::Error

class PasswordValidator < CQL::ActiveRecord::Validations::CustomValidator
  def initialize(@record : User)
  end

  def valid? : Array(Error)
    password = @record.password || ""
    errors = [] of Error
    errors << Error.new(:password, "must be at least 8 characters") if password.size < 8
    # The built-in predicates (presence?, gt?, match? ...) are available here
    errors << Error.new(:password, "must contain a digit") unless match?(password, /\d/)
    errors
  end
end

# There is no uniqueness option: check it here and back it with a unique index
class UniqueEmailValidator < CQL::ActiveRecord::Validations::CustomValidator
  def initialize(@record : User)
  end

  def valid? : Array(Error)
    existing = User.find_by(email: @record.email)
    return [] of Error unless existing && existing.id != @record.id
    [Error.new(:email, "has already been taken")]
  end
end

class User
  use PasswordValidator, UniqueEmailValidator
end
```

## See Also

- [Validation Options Reference](../../reference/api/validation-options.md)
- [Use Callbacks](use-callbacks.md)
- [Define a Model](define-model.md)
- [Fix Validation Errors](../troubleshooting/validation-errors.md)
- [Create Indexes](../migrations/indexes.md)
