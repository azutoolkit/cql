---
description: "A type-safe query builder and Active Record ORM for Crystal on SQLite, PostgreSQL, MySQL and CockroachDB."
icon: "house"
---

# CQL (Crystal Query Language)

Schemas, models and queries are Crystal code, so a misspelled column or a value of the wrong type fails at compile time, and every value reaches the database as a bound parameter. CQL ships its own PostgreSQL driver.

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

<table data-view="cards"><thead><tr><th></th><th></th><th data-hidden data-card-target data-type="content-ref"></th></tr></thead><tbody>
<tr><td><strong>Installation</strong></td><td>Add the shards for your database and check the connection.</td><td><a href="installation.md">installation.md</a></td></tr>
<tr><td><strong>Tutorials</strong></td><td>Learn CQL step by step, from a first app to a full blog.</td><td><a href="tutorials/README.md">tutorials/README.md</a></td></tr>
<tr><td><strong>How-to Guides</strong></td><td>One task per page: models, queries, migrations, caching, PostgreSQL.</td><td><a href="how-to/README.md">how-to/README.md</a></td></tr>
<tr><td><strong>Reference</strong></td><td>Every setting, DSL method, callback, validator and error.</td><td><a href="reference/README.md">reference/README.md</a></td></tr>
<tr><td><strong>Explanation</strong></td><td>How CQL works and why: Active Record, guardrails, performance.</td><td><a href="explanation/README.md">explanation/README.md</a></td></tr>
<tr><td><strong>Resources</strong></td><td>FAQ and how to contribute.</td><td><a href="resources/README.md">resources/README.md</a></td></tr>
</tbody></table>

Source, issues and releases: [azutoolkit/cql](https://github.com/azutoolkit/cql) on GitHub. CQL is available under the MIT license.
