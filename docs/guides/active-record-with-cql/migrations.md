# Database Migrations

Database migrations are a crucial part of managing your application's database schema in a structured and version-controlled way. CQL provides a migration system that allows you to evolve your database schema over time as your application's requirements change.

Migrations are Crystal classes that define how to apply changes (`up` method) and how to revert them (`down` method).

---

## What are Migrations?

As your application evolves, you'll often need to:

- Create new tables.
- Add, remove, or modify columns in existing tables.
- Add or remove indexes.
- Perform other schema alterations.

Migrations allow you to script these changes in Crystal code. Each migration file typically represents a single, atomic change to the database schema and is often timestamped or versioned to ensure changes are applied in the correct order.

**Benefits of using migrations:**

- **Version Control**: Schema changes are tracked in your project's version control system (e.g., Git) alongside your application code.
- **Collaboration**: Makes it easier for teams to manage database schema changes consistently across different development environments.
- **Reproducibility**: Ensures that the database schema can be recreated reliably in any environment (development, testing, production).
- **Automation**: Schema changes can be applied automatically as part of deployment processes.

---

## Defining a Migration

Migrations in CQL are Crystal classes that inherit from `CQL::Migration` (or a similar base class provided by the CQL framework).

1.  **File Naming and Location**: Migration files are typically placed in a `db/migrate/` directory within your project. The filename often includes a timestamp or a sequential version number to denote the order of execution, followed by a descriptive name for the migration (e.g., `db/migrate/20231027000000_create_users.cr`).

2.  **Migration Class Structure**:

    ```crystal
    # db/migrate/YYYYMMDDHHMMSS_create_users.cr
    # Replace YYYYMMDDHHMMSS with the actual timestamp for the migration.
    class CreateUsers < CQL::Migration
      # Optional: Define a version for this migration if not derived from filename.
      # self.version = 20231027000000_i64 # Example version

      # The `up` method describes the changes to apply to the database.
      def up(schema : CQL::Schema::Definition)
        # Example: Create a 'users' table
        schema.create_table :users do |t|
          # Define columns for the table
          t.primary_key :id             # Defines an auto-incrementing primary key named 'id'.
                                        # Specifics like `bigserial` for PostgreSQL might be abstracted or configurable.
          t.text :name, null: false       # A text column for user's name, cannot be null.
          t.text :email, null: false, unique: true # Email, cannot be null, must be unique.
          t.bool :active, default: false  # Boolean for active status, defaults to false.
          t.timestamps                    # Convenience method to add `created_at` and `updated_at` (both Time, nullable by default usually).
        end

        # Example: Adding an index separately (if not done in create_table)
        schema.add_index :users, :email, unique: true, name: "index_users_on_email_unique"
      end

      # The `down` method describes how to revert the changes made in the `up` method.
      def down(schema : CQL::Schema::Definition)
        # Example: Drop the 'users' table
        schema.drop_table :users
        # If you added an index separately in `up`, you might remove it here:
        # schema.remove_index :users, name: "index_users_on_email_unique" (or by column)
      end
    end
    ```

    **Key Points:**

    - **`class CreateUsers < CQL::Migration`**: Your migration class inherits from `CQL::Migration`.
    - **`up(schema : CQL::Schema::Definition)`**: This method is called when applying the migration. The `schema` object provides methods to manipulate the database structure.
    - **`down(schema : CQL::Schema::Definition)`**: This method is called when reverting (rolling back) the migration. It should undo the changes made by the `up` method.
    - **Schema Definition API**: The methods available on the `schema` object (e.g., `create_table`, `add_column`, `drop_table`, `add_index`) and the column definition block (e.g., `t.text`, `t.bool`, `t.primary_key`, `t.timestamps`) are specific to CQL. The exact syntax and available types (`:text`, `:integer`, `:bool`, `:datetime`, etc.) should be referenced from the CQL documentation you are using. The example above uses common conventions.

---

## Common Migration Operations

Here are some common operations you might perform within the `up` and `down` methods of a migration:

### Table Operations

- **Create Table** (`schema.create_table :table_name do |t| ... end`):

  ```crystal
  # up method
  schema.create_table :posts do |t|
    t.primary_key :id
    t.references :user, foreign_key: true # Creates user_id and a foreign key constraint
    t.text :title, null: false
    t.text :body
    t.datetime :published_at
    t.timestamps
  end
  ```

  ```crystal
  # down method
  schema.drop_table :posts
  ```

- **Drop Table** (`schema.drop_table :table_name`):
  Used in the `down` method to remove a table created in the `up` method.

- **Alter Table** (`schema.alter_table :table_name do |t| ... end`):
  Used for adding, removing, or changing columns on an existing table.

### Column Operations (within `create_table` or `alter_table`)

- **Add Column** (`t.add_column :column_name, :type, options...` or `schema.add_column :table, :column, :type, ...`):

  ```crystal
  # up method (inside alter_table)
  # schema.alter_table :users do |t|
  #  t.integer :login_count, default: 0
  # end
  # Or, if alter_table is not the direct way for add_column with CQL
  schema.add_column :users, :login_count, :integer, default: 0, null: false
  ```

  ```crystal
  # down method
  schema.remove_column :users, :login_count
  ```

- **Remove Column** (`t.remove_column :column_name` or `schema.remove_column :table, :column`):
  Used to drop a column.

- **Rename Column** (`schema.rename_column :table, :old_name, :new_name`):
  Changes the name of an existing column.

- **Change Column** (`schema.change_column :table, :column, :new_type, options...`):
  Modifies the type or other options (like `null`, `default`) of an existing column.
  ```crystal
  # up method
  # schema.change_column :users, :email, :text, limit: 255 # Example if changing type or options
  ```

### Index Operations

- **Add Index** (`schema.add_index :table_name, :column_name_or_columns, options...`):
  Indexes improve query performance on frequently searched columns.

  ```crystal
  # up method
  schema.add_index :posts, :user_id
  schema.add_index :posts, [:title, :published_at], name: "idx_posts_on_title_and_published_at"
  ```

- **Remove Index** (`schema.remove_index :table_name, :column_name_or_columns` or `name: :index_name`):
  ```crystal
  # down method
  schema.remove_index :posts, :user_id
  schema.remove_index :posts, name: "idx_posts_on_title_and_published_at"
  ```

### Foreign Keys

- Foreign keys can often be defined when creating columns (e.g., `t.references :author, foreign_key: true`) or added separately using methods like `schema.add_foreign_key`.

```crystal
# Assuming t.references in create_table does this.
# If not, explicitly:
# schema.add_foreign_key :posts, :users, column: :user_id, primary_key: :id
```

**Important**: The exact method names and options for schema manipulation (`create_table`, `add_column`, available data types like `:text`, `:integer`, `:bool`, options like `null:`, `default:`, `unique:`) can vary significantly between different database adapters (PostgreSQL, MySQL) and ORM/query builder implementations. **Always refer to the specific CQL documentation for the version you are using** to ensure you are using the correct API for schema definition.

---

## Running Migrations

CQL will typically provide command-line tools or Rake tasks (if integrated with Rake) to manage and run your migrations.

Common migration commands (exact syntax will depend on CQL's tooling):

- **`db:migrate`**: Applies all pending migrations (those that haven't been run yet).

  ```bash
  # Example placeholder command - replace with actual CQL command
  # crystal run path/to/cql/runner.cr db:migrate CONTEXT=YourDBContext
  # or if using Rake:
  # rake db:migrate
  ```

- **`db:rollback`**: Reverts the last applied migration.

  ```bash
  # rake db:rollback
  ```

- **`db:schema:load`**: Loads the schema from a schema file (e.g., `db/schema.cr` or `db/structure.sql`) into the database. This is often used to set up a new database quickly by loading the current schema state, bypassing running all migrations individually.

- **`db:schema:dump`**: Creates or updates a schema file based on the current state of the database. This file represents the authoritative structure of your database.

- **`db:reset`**: Typically drops the database, recreates it, and then loads the schema (or runs all migrations). Useful for resetting the database to a clean state in development.

- **Checking Migration Status**: Tools to see which migrations have been applied and which are pending.

**Database Context**: When running migrations, you often need to specify the database context (e.g., `CONTEXT=AcmeDB`) if your application uses multiple databases or if the migration runner needs to know which configuration to use.

---

## Schema File (`db/schema.cr` or `db/structure.sql`)

After migrations are run, CQL (like many ORMs) may maintain a `db/schema.cr` or `db/structure.sql` file.

- **`db/schema.cr` (if applicable)**: This would be a Crystal representation of your current database schema, generated by inspecting the database. It's often used by `db:schema:load`.
- **`db/structure.sql`**: Alternatively, a raw SQL dump of the database structure. This is database-agnostic for loading but less so for inspection.

This file serves as the canonical representation of your database schema at a given point in time. It's recommended to commit this file to version control.

---

Migrations are a powerful tool for database schema management. Writing reversible migrations (`up` and `down` methods) is crucial, especially for rolling back changes if needed.
Always test your migrations thoroughly, especially those involving data transformation or potentially destructive operations.
