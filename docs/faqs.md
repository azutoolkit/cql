# Frequently Asked Questions

Common questions about Crystal Query Language (CQL) and its Active Record implementation.

## General CQL Questions

**Q: What is CQL?**

A: CQL is an Object-Relational Mapping (ORM) library for Crystal that provides type-safe database interactions through an Active Record pattern with support for PostgreSQL, MySQL, and SQLite.

**Q: How do I install CQL?**

A: Add CQL to your `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: "~> 1.0"
```

Then run `shards install`. See the [Installation Guide](installation.md) for details.

**Q: Which databases does CQL support?**

A: CQL supports PostgreSQL, MySQL, and SQLite through Crystal DB drivers.

**Q: How does CQL compare to other ORMs?**

A: CQL leverages Crystal's compile-time type safety, provides zero-cost abstractions through macros, and supports multiple design patterns (Active Record, Repository, Data Mapper).

## Active Record Questions

**Q: How do I define a model?**

A: Create a Crystal struct with `CQL::ActiveRecord::Model`:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context UserDB, :users

  property id : Int64?
  property name : String
  property email : String
end
```

See [Defining Models](guides/active-record-with-cql/defining-models.md) for details.

**Q: How do I perform CRUD operations?**

A: Use built-in methods:

```crystal
# Create
user = User.create!(name: "Alice", email: "alice@example.com")

# Read
user = User.find!(1)
users = User.where(active: true).all

# Update
user.update!(name: "Alice Smith")

# Delete
user.delete!
```

See [CRUD Operations](guides/active-record-with-cql/crud-operations.md) for more examples.

**Q: How do I define relationships?**

A: Use association macros:

```crystal
struct User
  has_many :posts, Post
  has_one :profile, UserProfile
end

struct Post
  belongs_to :user, User
end
```

See [Relations](guides/active-record-with-cql/relations/README.md) for all relationship types.

**Q: How do validations work?**

A: Define validations in your model:

```crystal
struct User
  validates :name, presence: true, length: {minimum: 2}
  validates :email, presence: true, format: EMAIL_REGEX, uniqueness: true
end
```

See [Validations](guides/active-record-with-cql/validations.md) for details.

**Q: What are callbacks?**

A: Callbacks run code at specific points in a model's lifecycle:

```crystal
struct User
  before_save :normalize_email
  after_create :send_welcome_email

  private def normalize_email
    self.email = email.downcase.strip
  end
end
```

See [Callbacks](guides/active-record-with-cql/callbacks.md) for more information.

**Q: What's the difference between `save` and `save!`?**

A: Methods with `!` raise exceptions on failure, while methods without return `false`:

```crystal
user.save   # Returns true/false
user.save!  # Returns true or raises CQL::RecordInvalid

user = User.find(1)    # Returns user or nil
user = User.find!(1)   # Returns user or raises CQL::RecordNotFound
```

**Q: How do migrations work?**

A: Define schema changes in migration classes:

```crystal
class CreateUsers < CQL::Migration
  def up
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.timestamps

      t.index :email, unique: true
    end
  end

  def down
    drop_table :users
  end
end
```

See [Migrations](guides/active-record-with-cql/migrations.md) for details.

**Q: Does CQL support transactions?**

A: Yes, CQL provides transaction support:

```crystal
User.transaction do
  user1.save!
  user2.save!
  # Both succeed or both rollback
end
```

See [Transactions](guides/active-record-with-cql/transactions.md) for more examples.

## Troubleshooting

**Q: How do I debug SQL queries?**

A: Enable query logging in development:

```crystal
MyDB = CQL::Schema.define(
  :mydb,
  adapter: adapter,
  uri: uri,
  log_level: :debug  # Shows generated SQL
)
```

**Q: My queries are slow. How do I optimize them?**

A: Common optimization strategies:

- Add appropriate indexes to frequently queried columns
- Use `select` to limit returned columns
- Use `includes` or `joins` to avoid N+1 queries
- Implement pagination for large result sets

See [Performance Optimization](guides/performance-optimization.md) for details.

**Q: Where can I get help?**

A: Check the [Troubleshooting Guide](troubleshooting.md) or visit the CQL GitHub repository to report issues or ask questions.

**Q: How do I contribute to CQL?**

A: Visit the GitHub repository at `azutoolkit/cql` to report bugs, suggest features, or submit pull requests.
