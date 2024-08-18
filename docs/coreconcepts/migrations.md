# Migrations

Database migrations are essential for managing changes to your schema over time in a controlled manner. In CQL, migrations are handled through the `Migration` and `Migrator` classes. This guide will help you understand how to create, apply, rollback, and manage migrations using `Cql::Migrator` in your projects.

#### Why Use Migrations?

Migrations allow you to:

* Apply changes to your database schema over time.
* Roll back changes in case of errors or updates.
* Track applied and pending changes, ensuring consistency across environments.

***

#### Real-World Example: Creating and Applying Migrations

Let’s start with a simple example. Suppose we need to add a `users` table to our database with two columns: `name` and `age`.

```crystal
class CreateUsersTable < Cql::Migration
  self.version = 1_i64

  def up
    schema.alter :users do
      add_column :name, String
      add_column :age, Int32
    end
  end

  def down
    schema.alter :users do
      drop_column :name
      drop_column :age
    end
  end
end
```

#### Explanation

* **The `up` method**: Defines the changes to apply when the migration is run (e.g., adding new columns).
* **The `down` method**: Defines how to revert the changes (e.g., dropping columns).
* **Versioning**: Each migration is assigned a version number, which ensures migrations are run in the correct order.

***

#### Initializing the Schema and Migrator

Before applying migrations, you need to set up the schema and create an instance of the `Migrator`.

```crystal
schema = Cql::Schema.build(:my_db, adapter: Cql::Adapter::SQLite, uri: "sqlite3://db.sqlite3") do |s|
  ...
end

migrator = Cql::Migrator.new(schema)
```

The **migrator,** upon initialization, automatically creates a `schema_migrations` table to track which migrations have been applied.

***

#### Applying Migrations

To apply all pending migrations, simply call the `up` method on the `migrator` object:

```crystal
migrator.up
```

This will apply all pending migrations in order of their version numbers.

**Applying Migrations Up to a Specific Version**

You can also apply migrations up to a specific version:

```crystal
migrator.up_to(1_i64)
```

This will apply all migrations up to version `1_i64`.

***

#### Rolling Back Migrations

To roll back the last migration, use the `down` method:

```crystal
migrator.down
```

You can also roll back to a specific migration version:

```crystal
migrator.down_to(1_i64)
```

This rolls back all migrations down to version `1_i64`.

***

#### Redoing Migrations

If you want to rollback and then re-apply the last migration, use the `redo` method:

```crystal
migrator.redo
```

This first rolls back the last migration and then re-applies it.

***

#### Listing Migrations

You can list applied, pending, and rolled-back migrations with the following commands:

*   **List Applied Migrations**:

    ```crystal
    migrator.print_applied_migrations
    ```
*   **List Pending Migrations**:

    ```crystal
    migrator.print_pending_migrations
    ```
*   **List Rolled Back Migrations**:

    ```crystal
    migrator.print_rolled_back_migrations
    ```

These commands provide a clear view of the current state of your migrations, making it easy to track progress and issues.

***

#### Managing Migrations

**Checking the Last Applied Migration**

You can retrieve information about the last applied migration using:

```crystal
last_migration = migrator.last
puts last_migration
```

This gives you details about the last migration that was successfully applied.

***

#### Advanced Example: Managing Multiple Migrations

Here’s an example where we define multiple migrations and apply them sequentially:

```crystal
class CreateMoviesTable < Cql::Migration
  self.version = 2_i64

  def up
    schema.alter :movies do
      add_column :title, String
      add_column :release_year, Int32
    end
  end

  def down
    schema.alter :movies do
      drop_column :title
      drop_column :release_year
    end
  end
end

class CreateActorsTable < Cql::Migration
  self.version = 3_i64

  def up
    schema.alter :actors do
      add_column :name, String
    end
  end

  def down
    schema.alter :actors do
      drop_column :name
    end
  end
end

# Apply the migrations
migrator.up
```

* **Versioning** ensures that migrations are applied in the correct order.
* Each migration can be applied and rolled back independently, offering flexibility in managing your database schema.

***

#### Conclusion

The `Cql::Migrator` class makes it easy to manage database migrations in a structured and version-controlled manner. By following this guide, you can:

* Create and apply migrations to modify your schema.
* Roll back changes if needed.
* Track applied and pending migrations to keep your database consistent across environments.

This approach is essential for teams working on large applications where database changes need to be applied safely and consistently over time.
