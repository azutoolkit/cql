---
description: >-
  In this guide, we'll walk through using CQL with Crystal for setting up a
  database schema, defining records (models), establishing relationships between
  them, and handling migrations
---

# Active Record with Cql

Getting Started with Active Record, Relations, and Migrations in CQL

In this guide, we'll walk through using CQL with Crystal for setting up a database schema, defining records (models), establishing relationships between them, and handling migrations. This will be a foundational guide for developers who are familiar with Object-Relational Mapping (ORM) concepts from other frameworks like ActiveRecord (Rails), Ecto, or Hibernate, but are now learning CQL with Crystal.

***

### Prerequisites

Before getting started, ensure you have the following:

* Crystal language installed (latest stable version).
* PostgreSQL or MySQL set up locally or in the cloud.
* CQL installed in your Crystal project.

You can add CQL to your project by including it in your `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: "~> 0.1.0"
```

Run `shards install` to add the library to your project.

***

### Setting up CQL

First, you need to configure CQL in your application. Let's create a basic `config/database.cr` file for connecting to a PostgreSQL database:

```crystal
require "cql"

# Database configuration
CQL::DB.open("postgres://username:password@localhost:5432/myapp_development") do |db|
  CQL::DB.setup(db)
end
```

Replace the database connection string with your actual PostgreSQL or MySQL credentials.

***

### Creating the Database Schema

CQL uses migrations to manage the database schema, similar to Rails' ActiveRecord or Ecto's migrations.

1.  **Generate a migration**: CQL provides generators to create migration files.

    ```bash
    crystal lib/cql/bin/cql generate migration CreateUsers
    ```

    This will create a file in the `db/migrate` directory, for example, `20230817000000_create_users.cr`.
2.  **Edit the migration**: Let's define a `users` table in this migration:

    ```crystal
    # db/migrate/20230817000000_create_users.cr

    class CreateUsers < CQL::Migration
      def up
        schema.alter :users do
          text :name, null: false
          text :email, null: false, unique: true
          timestamps
        end
      end

      def down
        schema.alter :users do 
          drop_table :users
        end
      end
    end
    ```

    Here, we create a `users` table with columns `name`, `email`, and `timestamps`.
3.  **Run the migration**: After defining your migration, you can run it with:

    ```bash
    crystal lib/cql/bin/cql migrate
    ```

This command will execute all pending migrations and update your database schema.

***

### Defining Records (Models)

Now that the schema is ready, we can define the `User` record (model) that maps to the `users` table.

1.  **Create the Record**:

    ```crystal
    # src/models/user.cr
    struct User
      include Cql::Record(User, Int64)
      define AcmeDB, :users

      property id : Int64?
      property name : String
      property email : String
      property created_at : Time
      property updated_at : Time
    end
    ```

    The `User` model is mapped to the `users` table. Here, we've defined the fields for `id`, `name`, `email`, and timestamps. We also added basic validations for `name` and `email`.
2.  **Create Records**: You can now create user records using the `User` model.

    ```crystal
    user = User.new(name: "John Doe", email: "john@example.com")
    user.save
    ```

    This will insert a new record into the `users` table.
3.  **Query Records**: You can query users using the `User` model.

    ```crystal
    users = User.all
    user = User.find(1)
    ```

    `User.all` fetches all users, and `User.find(1)` fetches the user with ID `1`.

***

### Establishing Relations

CQL supports associations similar to ActiveRecord, Ecto, and other ORMs. Let's define some common relationships such as `has_many` and `belongs_to`.

**Example: Users and Posts**

1.  **Migration for Posts**:

    Create a new migration for the `posts` table.

    ```bash
    crystal lib/cql/bin/cql generate migration CreatePosts
    ```

    Edit the migration to add the `posts` table, which has a foreign key to the `users` table:

    ```crystal
    # db/migrate/20230817000001_create_posts.cr

    class CreatePosts < Cql::Migration
      
      schema.table :posts do
        primary 
        text :title, null: false
        text :body, null: false
        bigint :user_id, null: false, index: true
        timestamps
      end
        
      def up
        schema.alter :posts { AcmeDB.posts.create! }
      end

      def down
        schema.alter :posts { AcmeDB.posts.drop! }
      end
    end
    ```
2.  **Define the Post Model**:

    Now, let's define the `Post` record and establish the relationships.

    ```crystal
    # src/models/post.cr
    struct Post
      include Cql::Record(Post, Int64)
      define AcmeDB, :posts

      property id : Int64?
      property title : String
      property body : String
      property user_id : Int64
      property created_at : Time
      property updated_at : Time

      belongs_to :user, User
    end
    ```

    Here, the `Post` model includes a foreign key `user_id` and defines a `belongs_to` association to the `User` model.
3.  **Define the `User` model's association**:

    Update the `User` model to reflect the relationship with `Post`.

    ```crystal
    # src/models/user.cr
    class User
      include Cql::Record(User, Int64)
      define AcmeDB, :users

      column id : Int64?
      column name : String
      column email : String
      column created_at : Time
      column updated_at : Time

      has_many :posts, Post
    end
    ```

    This defines a `has_many` association on `User` so that each user can have multiple posts.
4. **Working with Relations**:
   *   Create a user and associate posts with them:

       ```crystal
       user = User.create(name: "Jane Doe", email: "jane@example.com")
       post = Post.new(title: "First Post", body: "This is the first post", user: user)
       post.save
       ```
   *   Access posts through the user:

       ```crystal
       user = User.find(1)

       user.posts.each do |post|
         puts post.title
       end
       ```

***

### Handling Migrations

CQL migrations allow you to create and alter your database schema easily. Here are some common migration tasks:

1.  **Adding Columns**:

    If you need to add a new column to an existing table, generate a migration:

    ```bash
    crystal lib/cql/bin/cql generate migration AddAgeToUsers
    ```

    Update the migration to add the `age` column:

    ```crystal
    class AddAgeToUsers < CQL::Migration
      def up
        schema.table :users do
          add_column :age, Int32
        end
      end

      def down
        schema.table :users do
          drop_column :age
        end
      end
    end
    ```
2.  **Rolling Back Migrations**:

    If something goes wrong with a migration, you can roll it back using:

    ```bash
    AcmeDB.migrator.rollback
    ```

    This will undo the last migration that was applied.

***

### Conclusion

This guide has provided a basic overview of using CQL with Crystal to define records (models), create relationships, and handle migrations. You've learned how to:

* Set up CQL and connect it to a database.
* Create and run migrations to define your schema.
* Define records and establish relationships using `has_many` and `belongs_to`.
* Manage your database schema with migrations.

With this foundation, you can now expand your models, add validations, and explore more advanced querying and relationships in CQL.\
\
In the following guide, we'll take a closer look at the different relationships you can establish between models in CQL: `BelongsTo`, `HasOne`, `HasMany`, and `ManyToMany`. These relationships allow you to associate models with one another, making it easy to retrieve related data, enforce foreign key constraints, and maintain data integrity.

We'll use simple examples with CQL's DSL to help you understand how to define and use these associations effectively.
