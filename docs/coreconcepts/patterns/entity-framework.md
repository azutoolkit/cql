# Entity Framework

In the context of CQL (Crystal Query Language), Entity Framework (EF) serves as a useful comparison to help developers understand how CQL and its features (like migrations, schema management, and object-relational mapping) work. Just as EF simplifies database interactions in .NET applications, CQL does the same for Crystal applications. Let’s break down the key concepts and approaches of EF and see how they align with CQL’s functionalities.

### 1. **Development Patterns**

In Entity Framework, developers have three approaches to database design: **Database-First**, **Code-First**, and **Model-First**. CQL shares some similarities, especially with the **Code-First** and **Database-First** approaches, but with Crystal-specific tooling.

#### **CQL's Schema-First Approach (Similar to Code-First)**

CQL primarily uses a **Schema-First** approach, where you define your database schema using Crystal code and CQL builds and manages the database based on this schema. This is similar to EF’s Code-First approach, where the developer defines the entity classes and EF generates the database schema.

Example in CQL:

```crystal
schema = Cql::Schema.build(:my_db, adapter: Cql::Adapter::SQLite, uri: "sqlite3://db.sqlite3") do |s|
  table :users do
    primary :id, Int32
    column :name, String
    column :age, Int32
  end
end
schema.init
```

This code defines the `users` table and its columns (`id`, `name`, and `age`), which CQL will use to generate the corresponding database structure.

### 2. **Core Concepts in CQL (Similar to EF Concepts)**

#### **Schema and Tables (Equivalent to EF’s `DbContext` and `DbSet`)**

In EF, a `DbContext` is used to manage the entities (mapped to database tables), and each `DbSet` represents a collection of entities (mapped to individual tables). Similarly, in CQL:

- `Cql::Schema` manages the structure of your database.
- Tables are defined within the schema using `table` blocks.

Example:

```crystal
schema = Cql::Schema.build(:my_db, adapter: Cql::Adapter::SQLite, uri: "sqlite3://db.sqlite3") do |s|
  table :products do
    primary :id, Int32
    column :name, String
    column :price, Float64
  end
end
```

This is similar to defining `DbSet<Product>` in EF, which represents the `products` table.

### **Migrations (Similar to EF Migrations)**

In CQL, migrations are a key feature, similar to EF’s migrations, for managing database schema changes over time. Migrations allow you to evolve your schema, apply changes, roll them back, and maintain a history of modifications.

Example migration in CQL:

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

In EF, migrations are handled using commands like `Add-Migration` and `Update-Database`. In CQL, migrations are applied and managed using the `Cql::Migrator` class, which provides methods for applying, rolling back, and listing migrations.

Applying migrations in CQL:

```crystal
migrator = Cql::Migrator.new(schema)
migrator.up  # Apply all pending migrations
```

This is similar to EF’s `Update-Database` command, which applies migrations to the database.

#### **Entities and Relationships (Similar to EF Entities and Navigation Properties)**

In CQL, database tables and columns are defined as part of the schema, and relationships like foreign keys can be established. This is comparable to how entities and relationships between them are managed in EF.

Example in CQL (adding a foreign key):

```crystal
schema = Cql::Schema.build(:my_db, adapter: Cql::Adapter::SQLite, uri: "sqlite3://db.sqlite3") do |s|
  table :orders do
    primary :id, Int32
    bigint :user_id
    text :order_date
    foreign_key :user_id, :users, :id, on_delete: "CASCADE"
  end
end
```

This defines an `orders` table with a foreign key relationship to the `users` table, similar to how EF handles one-to-many or many-to-many relationships.

### 3. **Life Cycle of Migrations and Schema Changes**

CQL’s migration life cycle aligns closely with EF’s migrations system. In both cases, you:

1. **Define migrations** to introduce schema changes.
2. **Apply migrations** to update the database schema.
3. **Rollback or redo migrations** if needed to manage schema changes.

#### **Example Migration Workflow in CQL:**

```crystal
migrator.up   # Apply pending migrations
migrator.down # Rollback the last migration
migrator.redo # Rollback and reapply the last migration
```

In EF, you would use commands like `Update-Database`, `Remove-Migration`, and `Add-Migration` to manage these operations.

### 4. **Querying the Database (CQL vs. EF’s LINQ to Entities)**

In EF, developers use LINQ to query entities and interact with the database. CQL also allows querying the database but through SQL-like syntax, aligning with Crystal’s programming style.

Example query in CQL:

```crystal
AcmeDB
  .query
  .from(:products)
  .select(:name, :price)
  .where(name: "Laptop")
  .all(Product)
```

This retrieves all products where the name is "Laptop", similar to how LINQ queries work in EF:

```csharp
var laptops = dbContext.Products.Where(p => p.Name == "Laptop").ToList();
```

Both frameworks provide abstractions that avoid writing raw SQL, but CQL maintains a more SQL-like approach in its query building.

### 5. **Advantages of Using CQL for Crystal Developers**

- **Productivity**: Like EF, CQL reduces the need for writing raw SQL by allowing developers to work with objects (schemas, tables, columns).
- **Schema Management**: CQL migrations simplify managing database changes, ensuring your schema evolves without breaking changes.
- **Consistency**: CQL’s Schema-First approach ensures the database schema is in sync with your application’s Crystal code, similar to EF’s Code-First approach.

---

#### Conclusion

CQL provides similar ORM-like features for Crystal that Entity Framework does for .NET. Whether using migrations, schema definitions, or querying data, both CQL and EF streamline database interactions, making it easier to manage complex applications. By understanding the core parallels between these two systems, Crystal developers can better leverage CQL’s powerful schema management and migration tools to build scalable and maintainable database-driven applications.
