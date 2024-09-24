# Altering the Schema

The `CQL::AlterTable` class in the CQL framework provides a structured way to make schema changes to your database tables. It allows you to perform actions like adding, dropping, and renaming columns, as well as adding foreign keys, renaming tables, and creating indexes. This guide walks you through the most common use cases with real-world examples that software developers can apply in their projects.

---

#### Why Use `CQL::AlterTable`?

When your application evolves, you often need to modify your database structure. `CQL::AlterTable` lets you:

- Add new columns to accommodate growing data needs.
- Remove or rename columns as your data model refines.
- Enforce foreign key relationships and maintain referential integrity.
- Create or remove indexes for performance tuning.

---

#### Real-World Example: Modifying the Users Table

Let’s start with a basic example where we modify the `users` table by adding a new column `email`, removing the `age` column, and renaming the `email` column to `user_email`.\
\
Given the **AcmeDB2** schema with a Users table:

```crystal
AcmeDB2 = CQL::Schema.build(
  :acme_db,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  table :users do
    primary
    text name, size: 150
  end
end
```

```crystal
alter_table = AlterTable.new(users_table, schema)

AcmeDB.alter :users do
  add_column(:email, "string", null: false, unique: true)
  drop_column(:age)
  rename_column(:email, :user_email)
end
```

This example:

- Adds a new `email` column that cannot be `NULL` and must be unique.
- Drops the `age` column, removing it from the table.
- Renames the `email` column to `user_email`.

---

### Core Methods in `CQL::AlterTable`

#### 1. `add_column(name : Symbol, type : Any, **options)`

**Purpose**: Adds a new column to the table with flexible options for setting the column's properties, such as type, default value, uniqueness, etc.

- **Parameters**:
  - `name`: The name of the column to add.
  - `type`: The data type of the column (e.g., `String`, `Int32`).
  - Additional options:
    - `null`: Whether the column can be `NULL` (default: `true`).
    - `default`: The default value for the column.
    - `unique`: Whether the column should have a unique constraint (default: `false`).
    - `size`: Optionally specify the size of the column (for strings or numbers).
    - `index`: Whether the column should be indexed (default: `false`).

**Real-World Example: Adding an Email Column**

```crystal
alter_table.add_column(:email, "string", null: false, unique: true)
```

This adds an `email` column to the table, ensures it is `NOT NULL`, and enforces a uniqueness constraint.

---

#### 2. `drop_column(name : Symbol)`

**Purpose**: Removes an existing column from the table.

- **Parameters**:
  - `name`: The name of the column to drop.

**Real-World Example: Dropping a Column**

```crystal
alter_table.drop_column(:age)
```

This removes the `age` column from the table.

---

#### 3. `rename_column(old_name : Symbol, new_name : Symbol)`

**Purpose**: Renames an existing column in the table.

- **Parameters**:
  - `old_name`: The current name of the column.
  - `new_name`: The new name for the column.

**Real-World Example: Renaming a Column**

```crystal
alter_table.rename_column(:email, :user_email)
```

This renames the `email` column to `user_email`.

---

#### 4. `change_column(name : Symbol, type : Any)`

**Purpose**: Changes the data type of an existing column.

- **Parameters**:
  - `name`: The name of the column.
  - `type`: The new data type for the column.

**Real-World Example: Changing a Column’s Type**

```crystal
alter_table.change_column(:age, "string")
```

This changes the `age` column’s type from whatever it was (likely an `Int32`) to a `string`.

---

#### 5. `rename_table(new_name : Symbol)`

**Purpose**: Renames the entire table.

- **Parameters**:
  - `new_name`: The new name for the table.

**Real-World Example: Renaming a Table**

```crystal
alter_table.rename_table(:customers)
```

This renames the table from `users` to `customers`.

---

#### 6. `foreign_key(name : Symbol, columns : Array(Symbol), table : Symbol, references : Array(Symbol), **options)`

**Purpose**: Adds a foreign key constraint to the table.

- **Parameters**:
  - `name`: The name of the foreign key.
  - `columns`: The columns in the current table to use as the foreign key.
  - `table`: The referenced table.
  - `references`: The columns in the referenced table.
  - Options:
    - `on_delete`: Action to take on delete (default: `NO ACTION`).
    - `on_update`: Action to take on update (default: `NO ACTION`).

**Real-World Example: Adding a Foreign Key**

```crystal
alter_table.foreign_key(:fk_movie_id, [:movie_id], :movies, [:id], on_delete: "CASCADE")
```

This adds a foreign key `fk_movie_id` on the `movie_id` column, linking it to the `id` column in the `movies` table. On delete, it cascades the delete.

---

#### 7. `drop_foreign_key(name : Symbol)`

**Purpose**: Removes a foreign key constraint from the table.

- **Parameters**:
  - `name`: The name of the foreign key to remove.

**Real-World Example: Dropping a Foreign Key**

```crystal
alter_table.drop_foreign_key(:fk_movie_id)
```

This drops the foreign key constraint `fk_movie_id` from the table.

---

#### 8. `create_index(name : Symbol, columns : Array(Symbol), unique : Bool = false)`

**Purpose**: Adds an index to the specified columns.

- **Parameters**:
  - `name`: The name of the index.
  - `columns`: The columns to index.
  - `unique`: Whether the index should enforce uniqueness (default: `false`).

**Real-World Example: Creating a Unique Index**

```crystal
alter_table.create_index(:index_users_on_email, [:email], unique: true)
```

This creates a unique index on the `email` column, ensuring that email addresses are unique across the table.

---

#### 9. `drop_index(name : Symbol)`

**Purpose**: Removes an index from the table.

- **Parameters**:
  - `name`: The name of the index to remove.

**Real-World Example: Dropping an Index**

```crystal
alter_table.drop_index(:index_users_on_email)
```

This drops the index `index_users_on_email` from the table.

---

#### 10. `to_sql(visitor : Expression::Visitor)`

**Purpose**: Generates the SQL string corresponding to the current set of table alterations.

- **Parameters**:
  - `visitor`: The SQL generator that converts the actions to SQL.

**Real-World Example: Generating SQL for Table Alterations**

```crystal
sql = alter_table.to_sql(visitor)
puts sql
```

This will generate the SQL statements that correspond to the actions taken (e.g., adding columns, dropping columns).

---

### Putting It All Together

Here’s an advanced example where we modify the `users` table by adding and removing columns, renaming the table, and creating an index:

```crystal
alter_table = AlterTable.new(users_table, schema)

sql = AcmeDB2.alter :users do
  add_column(:email, "string", null: false, unique: true)
  drop_column(:age)
  rename_table(:customers)
  create_index(:index_customers_on_email, [:email], unique: true)
end.to_sql

puts sql
```

This code:

1. Adds a `email` column with `NOT NULL` and `UNIQUE` constraints.
2. Drops the `age` column.
3. Renames the `users` table to `customers`.
4. Creates a unique index on the `email` column.
5. Generates the SQL statements that implement these actions.

---

#### Conclusion

The `CQL::AlterTable` class provides a simple and flexible interface for modifying your database schema. With its chainable methods, you can easily add, drop, or modify columns, rename tables, and manage foreign keys and indexes. This makes managing your database schema effortless, allowing you to focus on building robust, scalable applications.
