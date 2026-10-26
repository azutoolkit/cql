# Validation Options Reference

Every predicate the `validate` macro accepts, the value it takes, when it passes and its default message. The message is what `errors.map(&.message)` returns.

```crystal
validate :name, presence: true, size: 2..50, message: "Name is invalid"
```

`validate attribute, **options` stores the options per attribute: a second `validate` for the same attribute replaces the first, so put every rule for one attribute in one call. An unknown option or an attribute without a getter is a compile-time error (`CQL validation error in User: ...`).

## Predicates

| Option | Value | Passes when | Default message |
| :--- | :--- | :--- | :--- |
| **`presence`** | `true` | not `nil` and not `empty?` (value must respond to `empty?`, so not on numbers) | `name must be present` |
| **`required`** | `true` | not `nil`; `""` passes | `nick is required` |
| **`match`** | `Regex` | the `String` matches (the getter must be `String`, not `String?`) | `email must match the pattern /@/` |
| **`size`** | `Int32` or `Range` | `value.size` equals it, or is in the range (strings, arrays) | `code must have a size of 5`, `tags must have a size of 1..3` |
| **`gt`** | number or `Time` | `value > x` | `age must be greater than 0` |
| **`gte`** | number or `Time` | `value >= x` | `starts_at must be greater than or equal to Time.utc(2020, 1, 1)` |
| **`lt`** | number or `Time` | `value < x` | `age must be less than 150` |
| **`lte`** | number or `Time` | `value <= x` | `age must be less than or equal to 150` |
| **`eq`** | any | `value == x` | `priority must be equal to 1` |
| **`in`** | `Array` or `Range` | the value is included | `role must be included in ["admin", "user"]`, `rating must be included in 1..5` |
| **`exclude`** | `Array` or `Range` | the value is not included | `password must not be included in ["password", "123456"]` |
| **`confirmation`** | `Symbol` (another getter) | the two getters are equal | `password_confirmation confirmation doesn't match` |
| **`accept`** | `true`, a value, or an `Array` | `true`: one of `true "true" "1" "on" "yes"`; otherwise equal to the value or in the array | `terms must be accepted` |
| **`message`** | `String` | | Replaces the default message of every failing rule in that call |
| **`on`** | `Symbol` | | Do not use: the macro accepts it, but the model then fails to compile (`undefined macro variable 'context'`). |

A `nil` value fails every predicate, so rules on a nilable getter also reject `nil`. Messages interpolate the option's source text, as in `Time.utc(2020, 1, 1)`.

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)

  property name : String = ""
  property email : String = ""
  property age : Int32 = 0
  property role : String = "user"
  @[DB::Field(ignore: true)]
  property nick : String? = nil
  @[DB::Field(ignore: true)]
  property code : String = "12345"
  @[DB::Field(ignore: true)]
  property tags : Array(String) = [] of String
  @[DB::Field(ignore: true)]
  property priority : Int32 = 1
  @[DB::Field(ignore: true)]
  property starts_at : Time = Time.utc
  @[DB::Field(ignore: true)]
  property rating : Int32 = 3
  @[DB::Field(ignore: true)]
  property password : String? = nil
  @[DB::Field(ignore: true)]
  property password_confirmation : String? = nil
  @[DB::Field(ignore: true)]
  property terms : String? = nil

  validate :name, presence: true, size: 2..50
  validate :nick, required: true
  validate :email, match: /@/
  validate :code, size: 5
  validate :tags, size: 1..3
  validate :age, gt: 0, lte: 150
  validate :priority, eq: 1
  validate :starts_at, gte: Time.utc(2020, 1, 1)
  validate :role, in: ["admin", "user"]
  validate :rating, in: 1..5
  validate :password, exclude: ["password", "123456"]
  validate :password_confirmation, confirmation: :password
  validate :terms, accept: true

  def initialize
  end
end
```

## Methods

| Method | Returns | Behavior |
| :--- | :--- | :--- |
| **`record.errors`** | `Array(CQL::ActiveRecord::Validations::Error)` | Runs every rule and custom validator; rebuilt on each call. Each `Error` has `field : Symbol` and `message : String`. |
| **`record.valid?`** | `Bool` | `errors.empty?`. |
| **`record.validate!`** | `Bool` | `true`, or raises `CQL::ActiveRecord::Validations::ValidationError`, whose `message` joins the error messages with `,`. |
| `save`, `save!`, instance `create!`, `collection.create(**attrs)` | | Call `validate!`, so an invalid record raises instead of returning `false`. |
| `Model.create!(**attrs)`, `update!`, `insert_all`, `upsert_all` | | Do not validate. |

`errors`, `valid?` and `validate!` take an optional context argument; with `on:` unusable it has no effect.

```crystal
user = User.new
user.valid?                                  # => false
user.errors.map { |e| {e.field, e.message} } # => [{:name, "name must be present"}, ...]
user.validate!                               # raises ValidationError: "name must be present,name must have a size of 2..50,..."
```

## Custom validators

| API | Meaning |
| :--- | :--- |
| `class V < CQL::ActiveRecord::Validations::CustomValidator` | Subclass with `initialize(@record : Model)` and `valid? : Array(CQL::ActiveRecord::Validations::Error)`. Includes the predicate helpers (`gt?`, `presence?`, `match?`, ...). |
| `use V, ...` | Registers one or more validators on the model; their errors come before the `validate` rules' errors. |

```crystal
class DiscountValidator < CQL::ActiveRecord::Validations::CustomValidator
  def initialize(@record : Order)
  end

  def valid? : Array(CQL::ActiveRecord::Validations::Error)
    return [] of CQL::ActiveRecord::Validations::Error if @record.discount <= @record.total
    [CQL::ActiveRecord::Validations::Error.new(:discount, "cannot exceed total")]
  end
end

class Order
  include CQL::ActiveRecord::Model(Int64)

  property total : Float64 = 0.0
  property discount : Float64 = 0.0

  use DiscountValidator

  def initialize(@total : Float64 = 0.0, @discount : Float64 = 0.0)
  end
end

Order.new(10.0, 20.0).errors.map(&.message) # => ["cannot exceed total"]
```

There are no `format`, `uniqueness`, `length`, `numericality` or `inclusion` options. A `before_save` callback that returns `false` also stops a save, without adding errors.

## See Also

- [Add Validations](../../how-to/models/add-validations.md)
- [Fix Validation Errors](../../how-to/troubleshooting/validation-errors.md)
- [Callback Hooks Reference](callback-hooks.md)
- [Error Codes](../error-codes.md)
