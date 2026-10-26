---
description: "Read why a record is invalid, handle the exception save raises, and fix validations that do not compile or do not run."
---

# Fix Validation Errors

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

`errors` returns `Array(CQL::ActiveRecord::Validations::Error)`, one per failing predicate; [Validation Options Reference](../../reference/api/validation-options.md) lists each predicate's default message and `message:`.

## Handle the exception `save` raises

```text
CQL::ActiveRecord::Validations::ValidationError: name must be present,email must match the pattern ...
```

`save`, `save!` and the instance `create!` raise this on an invalid record; `save` does not return `false` for it. It is a `CQL::RecordInvalid`, so `rescue CQL::RecordInvalid` catches it too. The message joins the error messages with commas, and `error_fields` lists the failing attributes.

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
rescue ex : CQL::RecordInvalid
  puts ex.message      # "name must be present,email must match the pattern ..."
  puts ex.error_fields # [:name, :email]
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

```text
SQLite3::Exception: UNIQUE constraint failed: users.email
CQL::Postgres::UniqueViolation: ERROR: duplicate key value violates unique constraint "idx_users_email" (SQLSTATE 23505)
```

There is no `uniqueness` predicate, so a unique index raises these; to report a duplicate as a validation error, write a custom validator as in [Add Validations](../models/add-validations.md#write-a-custom-validator).

## Fix validations that do not compile

```text
Error: CQL validation error in Signup: unsupported predicate `format` for `:email`. Supported predicates: "eq, exclude, gt, gte, in, lt, lte, match, size, presence, required, confirmation, accept".
Error: CQL validation error in Signup: unknown attribute `:emial`. Define a readable property or getter for `:emial` before calling `validate ::emial`.
```

Use `match:` for formats and `gt:`/`lt:` for numbers, and declare the property before `validate`.

## Fix a rule that runs only sometimes

A rule declared with `on: :create` runs only while the record is new, and `on: :update` only once it is saved. `valid?` and `errors` follow the record's state, so check a new record with `user.valid?(:update)` to see the update rules.

## Test validations

Spec `valid?` and `errors` on records built with `new`, not with the class-level `create!`; see [Set Up Test Databases and Factories](../testing/test-database.md#build-records-with-factories).

## See Also

- [Add Validations](../models/add-validations.md)
- [Validation Options Reference](../../reference/api/validation-options.md)
- [Use Callbacks](../models/use-callbacks.md)
- [Create Records](../data-operations/create.md)
- [Fix Schema Mapping Errors](schema-mapping-errors.md)
