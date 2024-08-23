# Active Record

**Active Record** is a design pattern used in Object-Relational Mapping (ORM) that simplifies database access by linking database tables directly to classes in your application. Each class represents a table, and each instance of the class corresponds to a row in that table. Active Record makes it easy to perform CRUD (Create, Read, Update, Delete) operations on the database.

In the context of **CQL (Crystal Query Language)** and **Crystal**, the Active Record pattern can be implemented by leveraging the object-oriented nature of Crystal and the querying capabilities provided by CQL. Here's how you can think about the **Active Record pattern** using CQL:

#### Key Concepts of Active Record

1. **Table-Class Mapping**: Each class corresponds to a table in the database.
2. **Row-Object Mapping**: Each object is an instance of a class and corresponds to a row in the database table.
3. **Database Operations as Methods**: Methods on the object handle database interactions (e.g., `.save`, `.delete`, `.find`).
4. **Associations**: Relationships between tables (e.g., `belongs_to`, `has_many`) are handled within the class structure.
5. **Validation**: Logic to ensure data integrity is embedded within the class.

## Implementing Active Record in CQL

### **1. Define a Model**

In Active Record, a model is a class that represents a database table. The class will contain attributes (columns), methods for interacting with the data, and associations.

Here’s an example of a `User` model:

```crystal
struct User < Cql::Record(User, Int32)
  # Schame name AcmeDB, table name :users
  db_context AcmeDB, :users

  property id : Int32?
  property name : String
  property email : String
  property created_at : Time
  property updated_at : Time
end
```

In this example:

- `struct User` is used instead of `class User`
- `Include Cql::Record(User, Int32)` specifies that `User` is the model and the primary key is of type `Int32`.
- The model still contains the properties (`id`, `name`, `email`, `created_at`, `updated_at`), but now we delegate all Active Record-like operations (e.g., `save`, `delete`) to `Cql::Record`.

{% hint style="info" %}
Cql makes no assumptions about table names and it must be explicitly provided. \
\
**Schama name** AcmeDB, \
**Table name** :users

**define** AcmeDB, :users
{% endhint %}

### **2. Performing CRUD Operations**

In the Active Record pattern, CRUD operations (Create, Read, Update, Delete) are performed directly on the class and instance methods. Here’s how you can implement CRUD with CQL:

#### **Create (INSERT)**

To create a new record in the database, instantiate a new object of the model class and call `.save` to persist it:

```crystal
user = User.new
user.name = "John Doe"
user.email = "john.doe@example.com"
user.created_at = Time.now
user.updated_at = Time.now
user.save # INSERTS the new user into the database
```

This will generate an `INSERT INTO` SQL statement and persist the user in the `users` table.

#### **Read (SELECT)**

To retrieve records from the database, you can use class-level methods like `.find` or `.all`. For example:

- Fetch all users:

```crystal
users = User.all # SELECT * FROM users
```

- Find a user by `id`:

```crystal
user = User.find(1) # SELECT * FROM users WHERE id = 1
```

#### **Update**

To update an existing record, modify the object and call `.save` again. This will generate an `UPDATE` SQL statement:

```crystal
user = User.find(1)
user.name = "Jane Doe"
user.save # UPDATE users SET name = 'Jane Doe' WHERE id = 1
```

#### **Delete**

To delete a record, find the object and call `.delete`:

```crystal
user = User.find(1)
user.delete # DELETE FROM users WHERE id = 1
```

### **3. Associations**

Active Record also simplifies relationships between tables, such as `has_many` and `belongs_to`. In CQL, you can implement these relationships like this:

#### **has_many (One-to-Many Relationship)**

A `User` has many `Posts`. You can db_context the association like this:

```crystal
struct User < Cql::Record(User, Int32)

  property id : Int32?
  property name : String
  property email : String
  property created_at : Time
  property updated_at : Time

  has_many :posts, Post
end

struct Post < Cql::Record(Post, Int32)

  property id : Int32?
  property title : String
  property body : String
  property created_at : Time
  property updated_at : Time

  belongs_to :user, User
end
```

Now you can fetch the posts for a user:

```crystal
user = User.find(1)
posts = user.posts # SELECT * FROM posts WHERE user_id = 1
```

#### **belongs_to (Many-to-One Relationship)**

The `Post` class has a `belongs_to` relationship with `User`. This means each post belongs to a user:

```crystal
post = Post.find(1)
user = post.user # SELECT * FROM users WHERE id = post.user_id
```

### Managing HasMany and ManyToMany Collections

Here is a summary of the **collection methods** provided in the `Cql::Relations::Collection` and `Cql::Relations::ManyCollection` classes for managing associations in a one-to-many and many-to-many relationship in CQL:

#### **Collection Methods**

1. **`all`**:
   - Returns all associated records for the parent record.
   - **Example**: `movie.actors.all`
2. **`reload`**:
   - Reloads the associated records from the database.
   - **Example**: `movie.actors.reload`
3. **`ids`**:
   - Returns a list of primary keys for the associated records.
   - **Example**: `movie.actors.ids`
4. **`<<`**:
   - Adds a new record to the association and persists it to the database.
   - **Example**: `movie.actors << Actor.new(name: "Laurence Fishburne")`
5. **`empty?`**:
   - Checks if the association has any records.
   - **Example**: `movie.actors.empty?`
6. **`exists?(**attributes)`\*\*:
   - Checks if any associated records exist that match the given attributes.
   - **Example**: `movie.actors.exists?(name: "Keanu Reeves")`
7. **`size`**:
   - Returns the number of associated records.
   - **Example**: `movie.actors.size`
8. **`find(**attributes)`\*\*:
   - Finds associated records that match the given attributes.
   - **Example**: `movie.actors.find(name: "Keanu Reeves")`
9. **`create(**attributes)`\*\*:
   - Creates a new record with the provided attributes and associates it with the parent.
   - **Example**: `movie.actors.create(name: "Carrie-Anne Moss")`
10. **`create!(record)`**:
    - Creates and persists a new record with the provided attributes, raising an error if it fails.
    - **Example**: `movie.actors.create!(name: "Hugo Weaving")`
11. **`ids=(ids : Array(Pk))`**:
    - Associates the parent record with the records that match the provided primary keys.
    - **Example**: `movie.actors.ids = [1, 2, 3]`
12. **`delete(record : Target)`**:
    - Deletes the associated record from the parent record if it exists.
    - **Example**: `movie.actors.delete(Actor.find(1))`
13. **`delete(id : Pk)`**:
    - Deletes the associated record by primary key.
    - **Example**: `movie.actors.delete(1)`
14. **`clear`**:
    - Removes all associated records for the parent record.
    - **Example**: `movie.actors.clear`

#### **ManyCollection Additional Methods**

- In addition to the methods inherited from `Collection`, the `ManyCollection` class also manages associations through a join table in many-to-many relationships.

1. **`create(record : Target)`**:
   - Associates the parent record with the created record through a join table.
   - **Example**: `movie.actors.create!(name: "Carrie-Anne Moss")`
2. **`delete(record : Target)`**:
   - Deletes the association through the join table between the parent and associated record.
   - **Example**: `movie.actors.delete(Actor.find(1))`
3. **`ids=(ids : Array(Pk))`**:
   - Associates the parent record with the records matching the primary keys through the join table.
   - **Example**: `movie.actors.ids = [1, 2, 3]`

These methods provide powerful ways to interact with and manage associations between records in a CQL-based application using both one-to-many and many-to-many relationships.

### **4. Validation**

Active Record often includes validations to ensure that data meets certain criteria before saving. In CQL, you can add custom validation logic inside the class:

```crystal
struct User < Cql::Record(User, Int32)

  property id : Int32?
  property name : String
  property email : String
  property created_at : Time
  property updated_at : Time

  def validate
    raise "Name can't be empty" if name.empty?
    raise "Email can't be empty" if email.empty?
  end

  def save
    validate
    super # Calls the original save method provided by CQL::Entity
  end
end
```

In this example, before saving a user, the `validate` method is called to ensure that the name and email are not empty.

{% hint style="info" %}
Alternatively validations can be supported by other shards. \
For example [Schema](https://azutopia.gitbook.io/azu/validations) shard from the Azu Toolkit can be use to db_context validations
{% endhint %}

### **5. Migrations**

Although not strictly part of Active Record, migrations are commonly used with it to modify database schemas over time. In CQL, migrations can be written using a migration system to create and alter tables. For example:

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

This migration would create the `users` table with the specified columns.

## How CQL Implements Active Record Principles

- **Model Representation**: Each class (like `User`, `Post`) maps directly to a database table.
- **CRUD Operations**: Operations like `.save`, `.delete`, `.find`, and `.all` are built into the CQL framework, allowing for seamless interaction with the database.
- **Associations**: Relationships between models are defined using macros like `has_many` and `belongs_to`, which make querying associated records straightforward.
- **Encapsulation of Business Logic**: Validation and other business rules can be embedded directly into model classes.
- **Database Migrations**: Schema changes are managed through migrations, which help keep the database structure synchronized with the application's models.

#### Example Workflow with Active Record and CQL

1. **db_context your models**:
   - Create `User` and `Post` classes that correspond to `users` and `posts` tables.
2. **Run Migrations**:
   - Use migrations to create or modify the database schema.
3. **Perform CRUD operations**:
   - Create, read, update, and delete records using model methods like `.save` and `.delete`.
4. **Manage relationships**:
   - db_context associations like `has_many` and `belongs_to` to handle relationships between models.
5. **Enforce business rules**:
   - Use validation methods to ensure data integrity.

By following the **Active Record** pattern in CQL, you can build a robust data access layer in your Crystal application with minimal effort while keeping your code clean and maintainable.
