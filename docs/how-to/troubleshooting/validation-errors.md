# Fix Validation Errors

Read why a record is invalid, handle the exception `save` raises, and fix validations that do not compile or do not run.

## See what is invalid

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: AppDB, table: :users

  property name : String = ""
  property email : String = ""
  property username : String = ""
  property age : Int32 = 0

  validate :name, presence: true
  validate :email, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validate :username, required: true, size: 3..20
  validate :age, gt: 0, lt: 150

  def initialize(@name = "", @email = "", @username = "", @age = 0)
  end
end

user = User.new("", "invalid-email", "jo", -5)
user.valid? # => false
user.errors.each { |error| puts "#{error.field}: #{error.message}" }
# name: name must be present
# email: email must match the pattern /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
# username: username must have a size of 3..20
# age: age must be greater than 0
```

`errors` returns `Array(CQL::ActiveRecord::Validations::Error)`, one per failing predicate. Default messages:

| Predicate | Message |
|---|---|
| `presence: true` (fails on `nil` or empty) | `<field> must be present` |
| `required: true` (fails on `nil` only) | `<field> is required` |
| `match:`, `size:` | `<field> must match the pattern <regex>`, `<field> must have a size of <size>` |
| `gt:`, `gte:`, `lt:`, `lte:`, `eq:` | `<field> must be greater than <n>`, `... greater than or equal to`, `... less than`, `... less than or equal to`, `... must be equal to` |
| `in:`, `exclude:` | `<field> must be included in <list>`, `<field> must not be included in <list>` |
| `accept:`, `confirmation:` | `<field> must be accepted`, `<field> confirmation doesn't match` |

`message:` replaces the message of every predicate in that `validate` call.

## Handle the exception `save` raises

```text
CQL::ActiveRecord::Validations::ValidationError: name must be present,email must match the pattern ...
```

`save`, `save!` and the instance `create!` raise this on an invalid record; `save` does not return `false` for it, and `save!` never raises `CQL::RecordInvalid`. The message joins the error messages with commas.

```crystal
# ❌ Never reaches else: save raises before it can return false
if user.save
  redirect_to user
else
  render_errors user.errors
end

# ✅ Check first, or rescue
if user.valid?
  user.save!
else
  render_errors user.errors.map { |e| {field: e.field, message: e.message} }
end

begin
  user.save!
rescue ex : CQL::ActiveRecord::Validations::ValidationError
  puts ex.message
end
```

`save` returns `false`, and `save!` raises `CQL::RecordNotSaved: Failed to save the record`, only when a callback halts the save.

## Know which writes skip validation

```crystal
User.create!(name: "", email: "nope", username: "x", age: -1) # class-level create!: inserts without validating
user.update!(email: "not-an-email")                           # writes the attributes without validating
User.update_all({:age => 0})                                  # one UPDATE, no validation
```

## Catch duplicates

There is no `uniqueness` predicate. A unique index makes the database raise:

```text
SQLite3::Exception: UNIQUE constraint failed: users.email
CQL::Postgres::UniqueViolation: ERROR: duplicate key value violates unique constraint "idx_users_email" (SQLSTATE 23505)
```

To report it as a validation error, register a custom validator with `use`:

```crystal
class UniqueEmailValidator < CQL::ActiveRecord::Validations::CustomValidator
  def initialize(@record : User)
  end

  def valid? : Array(CQL::ActiveRecord::Validations::Error)
    errors = [] of CQL::ActiveRecord::Validations::Error
    if @record.id.nil? && User.where(email: @record.email).exists?
      errors << CQL::ActiveRecord::Validations::Error.new(:email, "email is already taken")
    end
    errors
  end
end

class User
  use UniqueEmailValidator
end
```

## Fix validations that do not compile

```text
Error: CQL validation error in Signup: unsupported predicate `format` for `:email`. Supported predicates: "eq, exclude, gt, gte, in, lt, lte, match, size, presence, required, confirmation, accept".
Error: CQL validation error in Signup: unknown attribute `:emial`. Define a readable property or getter for `:emial` before calling `validate ::emial`.
Error: undefined macro variable 'context'
```

Use `match:` for formats and `gt:`/`lt:` for numbers, and declare the property before `validate`. The last error comes from any `on:` option: contexts do not compile yet, so remove `on:`. `valid?`, `errors` and `validate!` accept a context argument, but without `on:` it changes nothing.

## Fix a validation that never fails

```crystal
# ❌ The second call replaces the first: "jo" passes, because size: is gone
validate :username, size: 3..20
validate :username, required: true

# ✅ One call per attribute, with every predicate
validate :username, required: true, size: 3..20
```

## Test validations

```crystal
describe User do
  it "requires a name" do
    user = User.new("", "ada@example.com", "ada", 36)
    user.valid?.should be_false
    user.errors.map(&.field).should contain(:name)
  end

  it "accepts valid data" do
    User.new("Ada", "ada@example.com", "ada", 36).valid?.should be_true
  end
end
```

## See Also

- [Add Validations](../models/add-validations.md)
- [Validation Options Reference](../../reference/api/validation-options.md)
- [Use Callbacks](../models/use-callbacks.md)
- [Create Records](../data-operations/create.md)
- [Fix Schema Mapping Errors](schema-mapping-errors.md)
