# Repository Pattern

A repository puts all database access for one kind of record behind one object, so domain code works with plain objects that know nothing about storage. CQL ships a generic repository, `CQL::Repository(T, Pk)`, and works well with repositories you write around a model.

```text
┌──────────────┐  find / save   ┌──────────────┐   SQL    ┌──────────────┐
│ Domain code  │ ─────────────> │  Repository  │ ───────> │   Database   │
│  (entities)  │ <───────────── │              │ <─────── │              │
└──────────────┘    entities    └──────────────┘   rows   └──────────────┘
```

## CQL::Repository Maps a Table to a Plain Record Type

The built-in repository is built from a schema and a table, and returns records of your own `DB::Serializable` type. No model, validations or callbacks are involved:

```crystal
struct UserRow
  include DB::Serializable
  include DB::Serializable::NonStrict # ignore table columns this struct does not declare

  getter id : Int64
  getter name : String
  getter email : String
end

users = CQL::Repository(UserRow, Int64).new(AppDB, :users)

id = users.create(name: "Ada", email: "ada@example.com") # => 1, the new primary key
users.find(id)                          # => UserRow? (nil when missing)
users.find_by(email: "ada@example.com") # => UserRow?
users.update(id, name: "Ada L.")
users.exists?(name: "Ada L.")           # => true
users.count                             # => 1
users.delete(id)
```

| Method | Returns |
| :--- | :--- |
| `find(id)`, `find_by(**fields)`, `first`, `last` | `T?`; `first` and `last` order by `id` |
| `find!(id)` | `T`, or raises `NilAssertionError` when missing |
| `all`, `find_all_by(**fields)`, `page(number, per_page = 10)`, `per_page(n)` | `Array(T)` |
| `exists?(**fields)` | `Bool` |
| `count` | the count, read as `Pk` |
| `create(**fields)`, `create(hash)` | the new key: `Int64` from `last_insert_id` on SQLite and MySQL, `Pk` from `RETURNING` on PostgreSQL and CockroachDB |
| `update(id, **fields)`, `delete(id)`, `delete_by(**fields)`, `delete_all` | `DB::ExecResult` |
| `query`, `insert`, `update`, `delete` | a `CQL::Query`, `Insert`, `Update` or `Delete` already scoped to the table |

CQL uses this class itself: the migrator stores its version rows through `CQL::Repository(CQL::MigrationRecord, Int32)`.

{% hint style="warning" %}
`count` reads `COUNT(*)` as the key type, so it raises `DB::ColumnTypeMismatchError` for a `String` key. `update(id, hash)`, `update_by`, `update_all` and `build` do not compile; use `update(id, **fields)` or the `update` builder.
{% endhint %}

## A Hand-Written Repository Keeps Model Features

Wrapping an Active Record model in your own repository keeps validations, callbacks and associations while the domain entity stays free of persistence code:

```crystal
# The domain entity: plain Crystal
class User
  property id : Int64?
  property name : String
  property email : String

  def initialize(@name : String, @email : String, @id : Int64? = nil)
  end
end

# The persistence model, used only by the repository
class UserRecord
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users

  property name : String
  property email : String
  property active : Bool = true

  validate :email, presence: true, match: /@/

  def initialize(@name : String, @email : String)
  end

  def to_entity : User
    User.new(name, email, id)
  end
end

class UserRepository
  def find(id : Int64) : User?
    UserRecord.find(id).try(&.to_entity)
  end

  def active : Array(User)
    UserRecord.where(active: true).all.map(&.to_entity)
  end

  # Raises CQL::ActiveRecord::Validations::ValidationError when the user is invalid
  def save(user : User) : Bool
    record = user.id.try { |id| UserRecord.find(id) } || UserRecord.new(user.name, user.email)
    record.name = user.name
    record.email = user.email
    saved = record.save
    user.id = record.id
    saved
  end

  def delete(user : User) : Bool
    record = user.id.try { |id| UserRecord.find(id) }
    record ? record.delete! : false
  end
end

repo = UserRepository.new
user = User.new("John", "john@example.com")
repo.save(user) # => true; INSERT, and user.id is set
user.name = "Johnny"
repo.save(user) # SELECT the record, then UPDATE users SET name = ?, email = ?, active = ? WHERE users.id = ?
repo.active.map(&.name) # => ["Johnny"]
```

`save` loads the stored record before changing it, so columns the entity does not carry (`active` here) keep their values instead of being reset to defaults.

## Repositories Make the Domain Testable Without a Database

Domain services depend on an abstract store, and tests pass an in-memory one:

```crystal
abstract class UserStore
  abstract def find(id : Int64) : User?
  abstract def save(user : User) : Bool
end

class InMemoryUserStore < UserStore
  @users = {} of Int64 => User

  def find(id : Int64) : User?
    @users[id]?
  end

  def save(user : User) : Bool
    user.id ||= @users.size.to_i64 + 1
    @users[user.id.not_nil!] = user
    true
  end
end

class SignupService
  def initialize(@store : UserStore)
  end

  def sign_up(name : String, email : String) : User
    User.new(name, email).tap { |user| @store.save(user) }
  end
end

SignupService.new(InMemoryUserStore.new).sign_up("Test", "test@example.com").id # => 1
```

In production, a `UserRepository < UserStore` like the one above implements the same two methods with CQL.

## When to Use It

| Good fit | Poor fit |
| :--- | :--- |
| Business rules that must not depend on storage | Simple CRUD, where the extra layer only adds code |
| Data from more than one source behind one interface | Prototypes, where Active Record is faster to write |
| Domain tests that should run without a database | Small projects with one data source |
| Large teams that want a clear boundary | |

The difference is small for one record and grows with the domain:

```crystal
id = user.id.not_nil!

# Active Record: the object saves itself
record = UserRecord.find!(id)
record.name = "Updated"
record.save

# Repository: the domain object is handed to the repository
entity = repo.find(id).not_nil!
entity.name = "Updated"
repo.save(entity)
```

The two patterns mix well: use models directly for plain CRUD, and a repository where the domain is complex. See [Active Record Pattern](active-record.md) for the model side.
