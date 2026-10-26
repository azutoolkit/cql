# CQL Blog Application Demo

A small blog on SQLite: four migrations, a seeder, four models and five demo modules, run in one program.

```bash
crystal run examples/blog/blog_demo.cr
```

> [!WARNING]
> Run from the repository root, and expect two files to change: `examples/blog/blog.db` (ignored by git) and
> `src/schemas/app_schema.cr`, which is tracked. `BlogDB.migrator` uses `CQL::MigratorConfig`'s default
> `schema_file_path`, so the schema file written after the migrations lands there instead of under
> `config.schema_dir`. Restore it with `git checkout src/schemas/app_schema.cr`.

`blog.cr` is not an entry point: it requires `./blog/blog_demo`, which does not exist, so it does not compile.

## Files

| Path | Contents |
| --- | --- |
| `blog_demo.cr` | `CQL.configure` (`db = "sqlite3://examples/blog/blog.db"`, `migrations_table = :cql_schema_migrations`, `auto_sync`, `bootstrap`, `verify_schema`, `monitor_performance`), then `BlogDemo.run` |
| `schemas/app_schema.cr` | `BlogDB = CQL::Schema.define(...)` with `users`, `categories`, `posts` and `comments`, plus the migrations table |
| `migrations/001_create_users.cr` to `004_create_comments.cr` | `CQL::Migration(1)` to `(4)`: one table each, with foreign keys and indexes |
| `models/` | `User`, `Category`, `Post`, `Comment`: structs including `CQL::ActiveRecord::Model(Int64)`, with `has_many` and `belongs_to` (`optional: true` for a post's category and a comment's user) |
| `seeders.cr` | `BlogDemo::Seeders.seed_data`: deletes all rows, then creates 2 users, 2 categories, 3 posts (2 published) and 2 comments |
| `demos/crud_operations.cr` | `count`, `find_by`, `where.order.limit`, `save!` after a change, `Comment.create!` |
| `demos/complex_queries.cr` | published posts with their authors (an N+1 on purpose), a raw `JOIN` through `BlogDB.exec`, `sum` and `avg`, per-category and per-author counts |
| `demos/relationships.cr` | `user.posts.where(...)`, `post.comments`, `comment.user`, `category.posts` |
| `demos/performance_features.cr` | `Post.find_each(batch_size: 2)`, `pluck(:title, as: String)` |
| `demos/statistics.cr` | `statistics_and_reporting`: counts, average word count, the most active author, a raw `GROUP BY` |

`BlogDemo.run` applies the migrations, seeds, calls `CQL::Performance.monitor.generate_report("logger")`, runs the
five demos in the order above and prints a summary.

## Known Output Problems

- The "Posts by Category" lines and "Tech category posts" print `#<CQL::Query:0x...>` instead of a number.
  `category.posts.where(published: true)` returns a `CQL::Query`, and its `count` adds a `COUNT` column instead of
  running the query; `.count.get(Int64)`, as the "Active Authors" lines use it, returns the number.
- No performance report appears: `generate_report` returns the report as a `String`, and the demo never prints it.
- The summary names `examples/blog/blog_demo.db`; the database is `examples/blog/blog.db`.

## See Also

- [Building a Blog](../../docs/tutorials/building-a-blog/01-project-setup.md): the same domain, built step by step
- [Configure CQL](../../docs/how-to/configuration/configure-cql.md#build_migrator-versus-schemamigrator): why
  `CQL.build_migrator(schema)` follows `CQL.config` and `schema.migrator` does not
- [Set Up Has Many](../../docs/how-to/relationships/has-many.md)
