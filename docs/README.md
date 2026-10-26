# CQL (Crystal Query Language)

CQL is a query builder and Active Record ORM for Crystal on SQLite, PostgreSQL, MySQL and CockroachDB. Schemas, models and queries are Crystal code, so a misspelled column or a value of the wrong type fails at compile time, and every value reaches the database as a bound parameter. CQL ships its own PostgreSQL driver.

```crystal
require "cql"
require "sqlite3"

AppDB = CQL::Schema.define(:app, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :users do
    primary :id, Int64, auto_increment: true
    text :name
  end
end

class User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users
  property name : String

  def initialize(@name : String)
  end
end

AppDB.users.create!
User.create!(name: "Ada")
User.where(name: "Ada").count # => 1   SELECT COUNT(*) FROM users WHERE users.name = ?
```

## Start Here

| You want to | Section | Start with |
| :--- | :--- | :--- |
| Add CQL to a project | [Installation](installation.md) | the `shard.yml` lines and a connection check |
| Learn CQL step by step | [Tutorials](tutorials/README.md) | [Your First CQL App](tutorials/getting-started/your-first-cql-app.md) |
| Get a specific task done | [How-to Guides](how-to/README.md) | [Configure Database Connection](how-to/configuration/database-connection.md) |
| Look up a method, option or error | [Reference](reference/README.md) | [Quick Reference](reference/quick-reference.md) |
| Understand how CQL works and why | [Explanation](explanation/README.md) | [What is an ORM?](explanation/concepts/what-is-orm.md) |
| Get help or contribute | [Resources](resources/README.md) | [FAQ](resources/faq.md) |

Source, issues and releases: [azutoolkit/cql](https://github.com/azutoolkit/cql) on GitHub. CQL is available under the MIT license.
