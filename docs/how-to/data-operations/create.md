---
description: "Insert rows with save, create! or insert_all, and know which of them validate."
---

# Create Records

## Build and Save

```crystal
user = User.new("Ada", "ada@example.com")
user.save        # => true
# INSERT INTO users (name, email, age, active, status, role, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
user.id          # => 1
user.persisted?  # => true
user.created_at  # set by save, like updated_at
```

`save` runs the validations and the `before_*` / `after_*` callbacks, then writes every property that is a column.

## Handle an Invalid Record

```crystal
user = User.new("", "not-an-email")

# save returns false for an invalid record and writes nothing
unless user.save
  user.errors.each { |error| puts "#{error.field}: #{error.message}" }
  # name: can't be blank
  # email: is not an email
end

# save! raises instead
begin
  user.save!
rescue ex : CQL::RecordInvalid
  ex.error_fields # => [:name, :email]
end
```

| Outcome | `save` | `save!` |
| :--- | :--- | :--- |
| Saved | `true` | `true` |
| Invalid | `false` | raises `ValidationError` (a `CQL::RecordInvalid`) |
| A callback returned `false` | `false` | raises `CQL::RecordNotSaved` |

## Create in One Step

```crystal
user = User.create!(name: "Grace", email: "grace@example.com")
# INSERT INTO users (name, email) VALUES (?, ?)
# SELECT users.id, users.name, ... FROM users WHERE users.id = ? LIMIT ?
user.id      # => 2
user.status  # => "pending", the schema's column default
user.role    # => "user"
user.created_at # the timestamps column default

User.create!(name: "Linus", email: "l@example.com", nickname: "x") # keys that are not columns are ignored

# Finds the row, or creates it
User.find_or_create_by(email: "ada@example.com")
```

`create!` returns the row as stored. PostgreSQL and CockroachDB get it from `INSERT ... RETURNING`; SQLite and MySQL
read it back by id. A model with its own `self.query` (a tenant filter, a soft-delete scope) reads it back through
that scope, so a row outside the scope makes `create!` raise `DB::NoResultsError` after inserting.

{% hint style="danger" %}
`User.create!(**fields)` and `find_or_create_by` run no validations and no callbacks: `User.create!(name: "", email: "nope")` inserts the row. Use `User.new(...).save` when the rules must hold.
{% endhint %}

## Create Related Records

```crystal
author = User.find_by!(email: "ada@example.com")
post = Post.create!(title: "My First Post", body: "Hello", user_id: author.id!)
post.user.try(&.name) # => "Ada"
```

## Insert Many Rows at Once

```crystal
User.insert_all([
  {name: "Alice", email: "alice@example.com"},
  {name: "Bob", email: "bob@example.com"},
]) # => 2
# INSERT INTO users (name, email, created_at, updated_at) VALUES (?, ?, ?, ?), (?, ?, ?, ?)

User.insert_all(rows, batch_size: 200)            # rows per statement; at most max_bind_params / columns
                                                  # (max_bind_params: 999 on SQLite, 32767 elsewhere)
User.insert_all([{name: "X", nickname: "y"}])     # ArgumentError: Unknown columns for users: nickname

# Rows that match on email update instead of failing
User.upsert_all([{email: "alice@example.com", name: "Alice L."}], on_conflict: :email)
```

No validations or callbacks run and no records come back. Missing timestamps get the current time, and UUID or ULID
keys get ids. Unknown columns, rows with different keys or a bad `batch_size` raise `ArgumentError` before anything
is inserted. Several statements run in one transaction.

[Upsert Records](upsert.md) covers `upsert_all` options.

## Read Columns Back From Your Own Insert

```crystal
# PostgreSQL and CockroachDB
# INSERT INTO users (name) VALUES ($1) RETURNING users.id, users.name
id, name = AppDB.insert.into(:users).values(name: "Ada").back(:id, :name).get!({Int64, String})
```

`get(as:)` returns `nil` when `on_conflict(...).do_nothing` skips the row; `get!` raises `DB::NoResultsError`
instead. Without `back` both raise `ArgumentError`, and on SQLite and MySQL `CQL::DialectError`, before anything is
inserted.

## See Also

- [Update Records](update.md)
- [Delete Records](delete.md)
- [Use Transactions](transactions.md)
- [Add Validations](../models/add-validations.md)
- [Use Callbacks](../models/use-callbacks.md)
- [Upsert Records](upsert.md)
