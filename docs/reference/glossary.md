# Glossary

CQL terms and the API each one names.

| Term | Meaning | API |
| :--- | :--- | :--- |
| Active Record | Objects that carry a row's data and its persistence methods | `include CQL::ActiveRecord::Model(Int64)` |
| Adapter | The database a schema talks to; picks the dialect and driver | `CQL::Adapter::SQLite`, `Postgres`, `MySql`, `CockroachDB` |
| Association | A link between two models | `belongs_to`, `has_one`, `has_many`, `many_to_many` |
| Belongs to | The model holds the foreign key of its parent | `belongs_to :user, User, :user_id` |
| Callback | A method run before or after validation, save or delete; returning `false` halts | `before_save :normalize_email` |
| Column | A field of a table, declared in the schema and mapped by a model property | `column :email, String` |
| `CQL::Query` | The SQL builder `AppDB.query` returns | `AppDB.query.from(:users).where(name: "Ada")` |
| Database context | The schema and table a model maps to; inferred when omitted | `db_context AppDB, :users` |
| Dialect | The per-database SQL rules (placeholders, upserts, DDL) | `CQL::Adapter::Postgres.dialect` |
| Dirty tracking | Opt-in change tracking; updates send only changed columns | `include CQL::ActiveRecord::DirtyTracking` |
| Down migration | The `down` method that reverts a migration | `migrator.rollback` |
| Foreign key | A column referencing another table's primary key | `foreign_key [:user_id], references: :users` |
| Has many | The parent of many rows that hold its key | `has_many :posts, Post, :user_id` |
| Has one | The parent of one row that holds its key | `has_one :profile, Profile, :user_id` |
| Index | A database structure that speeds lookups on columns | `index [:email], unique: true` |
| Join model | The model of a many-to-many join table | `many_to_many :tags, Tag, join_through: PostTag` |
| Migration | A versioned schema change | `class CreateUsers < CQL::Migration(1)` |
| Migrator | Applies and reverts migrations and keeps the schema file | `AppDB.migrator(config).up` |
| Model | A class mapped to a table | `class User; include CQL::ActiveRecord::Model(Int64); end` |
| Optimistic locking | Detecting concurrent updates with a version column | `optimistic_locking version_column: :lock_version` |
| Preload | Loading an association for many records with one extra query | `Post.preload(:user).all` |
| Primary key | The unique identifier of a row (`Int32`, `Int64`, `UUID` or ULID `String`) | `primary :id, Int64, auto_increment: true` |
| `QueryBuilder` | The typed query `Model.query` and `Model.where` return | `User.where(active: true).order(id: :desc)` |
| Repository | A table-level data access object without a model class | `CQL::Repository(User, Int64).new(AppDB, :users)` |
| Schema | The database connection and its declared tables | `AppDB = CQL::Schema.define(:app_db, adapter:, uri:) { ... }` |
| Schema file | The generated Crystal file that mirrors the database | `migrator.update_schema_file` |
| Scope | A named, chainable query on a model | `scope :published, -> { where(published: true) }` |
| Soft delete | Marking rows deleted with `deleted_at` instead of removing them | `include CQL::ActiveRecord::SoftDeletable` |
| Telemetry | The event stream for every statement and transaction | `CQL::Telemetry.subscribe("log") { \|event\| ... }` |
| Timestamps | `created_at` and `updated_at`, set by `save` | `timestamps` |
| Transaction | Statements that commit or roll back together | `User.transaction { ... }` |
| Up migration | The `up` method that applies a migration | `migrator.up` |
| Validation | A rule a record must pass before it is saved | `validate :email, match: /@/` |
| Version column | The `Int32` column optimistic locking increments | `lock_version` |

## See Also

- [Quick Reference](quick-reference.md)
- [Define a Model](../how-to/models/define-model.md)
- [Explanation](../explanation/README.md)
