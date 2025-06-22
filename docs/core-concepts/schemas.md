# DB Schema

## Accelerating Database Iteration

Defining the schema first is a fundamental approach in CQL, helping developers quickly structure their database while keeping their application's data model in sync with real-world entities. By defining your schema upfront, you can rapidly iterate over your database tables, making it easy to adjust data structures as your application evolves. This method ensures that your schema is the single source of truth, giving you a clear view of how your data is organized and how relationships between different tables are modeled.

<div data-full-width="true">

<figure><img src="../.gitbook/assets/Untitled.svg" alt=""><figcaption></figcaption></figure>

</div>

## Benefits of Defining the Schema First

1. **Faster Prototyping**: With schemas defined at the outset, you can rapidly experiment with different table structures and relationships, making it easier to adjust your application's data model without writing complex migrations from scratch.
2. **Clear Data Structure**: When your schema is predefined, the application's data structure becomes clearer, allowing developers to conceptualize how data is organized and interact with tables more easily.
3. **Consistency**: Ensuring the schema matches the database at all times removes ambiguity when writing queries, handling relationships, or performing migrations.
4. **Automatic Data Validation**: CQL schemas enforce data types and constraints, such as `primary`, `auto_increment`, and `text`, ensuring data integrity.
5. **Simplified Query Building**: Since the schema is explicit, writing queries becomes easier as you can reference schema objects directly in queries, avoiding mistakes or typos in table or column names.

## **Difference from Other ORM Libraries**

Unlike traditional ORM libraries (e.g., Active Record in Rails or Ecto in Elixir), which often allow defining database models alongside the code and handling schema evolution through migrations, CQL encourages defining the database schema as the first step.

This "schema-first" approach differs from the "code-first" or "migration-based" methodologies in that it avoids relying on automatic migrations or conventions to infer the structure of the database. CQL enforces an explicit and structured approach to schema creation, ensuring the database schema reflects the actual architecture of your application.

## **Example Schema Definition**

Here's a basic example of how to define a schema in CQL for a movie-related database:

```crystal
AcmeDB2 = CQL::Schema.build(
  :acme_db,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]) do

  table :movies do
    primary :id, Int64, auto_increment: true
    text :title
  end

  table :screenplays do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    text :content
  end

  table :actors do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :directors do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    text :name
  end

  table :movies_actors do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    bigint :actor_id
  end
end
```

## Explanation of Schema Definition

- **Database name**: `:acme_db` defines the schema name.
- **Adapter**: `CQL::Adapter::Postgres` specifies the database adapter (in this case, PostgreSQL).
- **Connection URL**: The `uri: ENV["DATABASE_URL"]` specifies the database connection using environment variables.

Each table is explicitly defined with its columns, such as:

- `:movies` table has `id` as the primary key and `title` as a `text` column.
- `:screenplays`, `:actors`, and `:directors` define relationships between movies and associated records.

This example shows how easy it is to define tables and manage relationships within the schema, leading to a more organized and coherent database structure that aligns with the application's needs.

---

## Table Operations

CQL provides comprehensive table operations for managing your database tables. These operations allow you to create, modify, and manage tables programmatically.

### Table Creation

You can create tables using the `create!` method:

```crystal
table = schema.table(:customers) do
  primary :id, Int32
  column :name, String
  column :city, String
  column :email, String
  column :balance, Int32
  timestamps
end

# Create the table in the database
table.create!
```

### Table Validation

CQL validates table names to ensure they follow proper naming conventions:

```crystal
# Valid table name
table = schema.table(:customers) do
  primary :id, Int32
end

# Invalid table names will raise errors
expect_raises(CQL::Error, "Table name cannot be empty") do
  schema.table(:"") do
    primary :id, Int32
  end
end

expect_raises(CQL::Error, "Table name cannot contain spaces") do
  schema.table(:"my table") do
    primary :id, Int32
  end
end

expect_raises(CQL::Error, "Table name cannot start with a number") do
  schema.table(:"1users") do
    primary :id, Int32
  end
end
```

### Column Operations

#### Primary Key Columns

```crystal
table = schema.table(:customers) do
  primary :id, Int64
end

primary = table.primary(:id, Int64)
primary.should be_a(CQL::PrimaryKey(Int64))
primary.name.should eq :id
primary.as(CQL::PrimaryKey(Int64)).auto_increment?.should be_true
primary.as(CQL::PrimaryKey(Int64)).unique?.should be_true
```

#### Regular Columns

```crystal
table = schema.table(:customers) do
  column :name, String
end

column = table.column(:name, String)
column.should be_a(CQL::Column(String))
column.name.should eq :name
column.null?.should be_false
```

#### Indexed Columns

```crystal
table = schema.table(:customers) do
  column :email, String, index: true, unique: true
end

column = table.column(:email, String, index: true, unique: true)
column.should be_a(CQL::Column(String))
column.index?.should_not be_nil
column.index?.not_nil!.unique?.should be_true
```

#### Timestamps

```crystal
table = schema.table(:customers) do
  timestamps
end

table.timestamps
table.columns[:created_at]?.should_not be_nil
table.columns[:updated_at]?.should_not be_nil
```

### Table Management Operations

#### Truncating Tables

Remove all data from a table while keeping the table structure:

```crystal
table = schema.table(:customers) do
  primary :id, Int32
  column :name, String
  column :city, String
  column :email, String
  column :balance, Int32
  timestamps
end

table.create!

# Insert some data
schema.insert.into(:customers).values([
  {name: "John", city: "New York", email: "john@example.com", balance: 100},
  {name: "Jane", city: "New York", email: "jane@example.com", balance: 200}
]).commit

# Verify data exists
count = schema.query.from(:customers).count.get(Int64)
count.should eq 2

# Truncate the table
table.truncate!

# Verify table is empty
count = schema.query.from(:customers).count.get(Int32)
count.should eq 0
```

#### Dropping Tables

Remove a table completely from the database:

```crystal
table = schema.table(:customers) do
  primary :id, Int32
  column :name, String
  column :city, String
  column :email, String
  column :balance, Int32
  timestamps
end

table.create!

# Drop the table
table.drop!

# Verify table no longer exists
expect_raises(DB::NoResultsError) do
  schema.exec_query(&.query_one("SELECT name FROM sqlite_master WHERE type='table' AND name='customers'", as: String))
end
```

### SQL Generation

CQL can generate SQL statements for table operations:

#### Create Table SQL

```crystal
table = schema.table(:customers) do
  primary :id, Int32, auto_increment: false
  column :name, String
  column :city, String
  column :balance, Int32
end

sql = table.create_sql
sql.should contain("CREATE TABLE IF NOT EXISTS customers")
sql.should contain("id INTEGER PRIMARY KEY")
sql.should contain("name TEXT NOT NULL")
sql.should contain("city TEXT NOT NULL")
sql.should contain("balance INTEGER NOT NULL")
```

#### Drop Table SQL

```crystal
table = schema.table(:customers) do
  primary :id, Int32
  column :name, String
  column :city, String
  column :balance, Int32
end

sql = table.drop_sql
sql.should eq("DROP TABLE IF EXISTS customers")
```

#### Truncate Table SQL

```crystal
table = schema.table(:customers) do
  primary :id, Int32
  column :name, String
  column :city, String
  column :balance, Int32
end

sql = table.truncate_sql
sql.should eq("DELETE FROM customers")
```

### Table Aliases

You can define table aliases for use in queries:

```crystal
schema = CQL::Schema.define(:test_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}") do
  table :users, as: :u do
    primary :id, Int32
    column :name, String
  end
end

table = schema.tables[:users]
table.as_name.should eq "u"
```

### Best Practices

1. **Always validate table names**: Use descriptive, valid table names that follow naming conventions.

2. **Use appropriate data types**: Choose the right data types for your columns to ensure data integrity and performance.

3. **Include timestamps**: Use the `timestamps` method to automatically add `created_at` and `updated_at` columns.

4. **Add indexes for performance**: Use indexes on columns that are frequently queried or used in joins.

5. **Test table operations**: Always test table creation, modification, and deletion operations in a development environment.

6. **Backup before destructive operations**: Always backup your data before performing truncate or drop operations.

---

#### **Multiple Schemas: Flexibility and Easy Switching**

One significant advantage of CQL is the ability to define and manage multiple schemas within the same application. This is particularly useful in scenarios like multi-tenant applications, where each tenant or environment has a separate database schema. CQL makes switching between schemas seamless, enabling developers to organize different parts of the application independently while maintaining the same connection configuration.

This approach offers the following benefits:

- **Clear Separation of Data**: Each schema can encapsulate its own set of tables and relationships, allowing better isolation and separation of concerns within the application. For example, you might have a `main` schema for core business data and a separate `analytics` schema for reporting.
- **Simple Switching**: Switching between schemas is as simple as referring to the schema name, thanks to CQL's structured definition of schemas. This allows dynamic switching at runtime, improving scalability in multi-tenant applications.

#### **Example: Managing Multiple Schemas**

```crystal
MainDB = CQL::Schema.build(:main, adapter: CQL::Adapter::Postgres, uri: ENV["MAIN_DB_URL"]) do
  # Define main schema tables
end

AnalyticsDB = CQL::Schema.build(:analytics, adapter: CQL::Adapter::Postgres, uri: ENV["ANALYTICS_DB_URL"]) do
  # Define analytics schema tables
end
```

In this example, you define multiple schemas, and the application can easily switch between `MainDB` and `AnalyticsDB` depending on which database needs to be queried.

#### **Benefits of Multiple Schemas**

- **Improved Organization**: Separate business logic data from other concerns like reporting, testing, or archiving.
- **Scalability**: Ideal for multi-tenant applications, allowing each tenant to have its schema without interference.

By using CQL's schema system, you gain not only speed and clarity in your database structure but also flexibility in scaling and organizing your application.
