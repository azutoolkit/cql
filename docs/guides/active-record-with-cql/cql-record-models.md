# CQL Record Models

The `CQL::Record` module in the CQL toolkit is a crucial part of the Object-Relational Mapping (ORM) system in Crystal. It allows you to define models that map to tables in your database and provides a wide array of functionalities for querying, inserting, updating, and deleting records. In this guide, we'll explore how the `CQL::Record` module works and how to use it effectively.

### **What is the `Record` Module?**

The `CQL::Record` module is a mixin that provides your Crystal structs with the ability to interact with database tables, treating them as Active Record-style models. This means that each model represents a table in your database, and each instance of that model represents a row within that table.

---

## Basic Setup: Defining a Schema

To start working with CQL models, you first need to define your database schema and map models (Crystal structs) to tables within that schema.

### **Example Schema**

Let's assume we have two tables: `posts` and `comments`. Each post can have many comments, and each comment belongs to one post.

```crystal
AcmeDB = CQL::Schema.define(
  :acme_db,
  adapter: CQL::Adapter::Postgres,
  uri: "postgresql://example:example@localhost:5432/example"
) do
  table :posts do
    primary :id, Int64, auto_increment: true
    text :title
    text :body
    timestamp :published_at
  end

  table :comments do
    primary :id, Int64, auto_increment: true
    bigint :post_id
    text :body
  end
end
```

- **posts table**: Contains columns `id`, `title`, `body`, and `published_at`.
- **comments table**: Contains columns `id`, `post_id` (foreign key), and `body`.

---

## Defining Models with `Record`

Now, let's define the `Post` and `Comment` models that map to the `posts` and `comments` tables.

### **Post Model**

```crystal
struct Post < CQL::Record(Int64)
  db_context AcmeDB, :posts

  getter id : Int64?
  getter title : String
  getter body : String
  getter published_at : Time

  # Initializing a new post
  def initialize(@title : String, @body : String, @published_at : Time = Time.utc)
  end
end
```

### **Comment Model**

```crystal
struct Comment <CQL::Record(Int64)
  db_context AcmeDB, :comments

  getter id : Int64?
  getter post_id : Int64
  getter body : String

  # Initializing a new comment
  def initialize(@post_id : Int64, @body : String)
  end

  # Each comment belongs to a post
  belongs_to :post, Post
end
```

### Key Features of the `Record` Module

The `CQL::Record` module adds several useful methods and features to your model:

**1. Defining Models with `define`**

Each model must be linked to a schema and a table using the `define` method.

```crystal
define AcmeDB, :posts
```

This associates the `Post` struct with the `posts` table in the `AcmeDB` schema.

## **Querying Records**

The `Record` module provides convenient methods for querying the database.

- **Fetching All Records**:

```crystal
posts = Post.all
```

This retrieves all the records from the `posts` table.

- **Fetching a Record by ID**:

```crystal
post = Post.find(1)
```

This retrieves the post with ID `1`. If the record is not found, `nil` is returned.

- **Fetching the First or Last Record**:

```crystal
first_post = Post.first
last_post = Post.last
```

These methods fetch the first and last records in the table, respectively.

- **Fetching Records with Conditions**:

```crystal
active_posts = Post.find_all_by(active: true)
post_by_title = Post.find_by(title: "My First Post")
```

These methods allow you to filter records by specific fields.

## **Creating Records**

You can create new records using the `create` method.

```crystal
post_id = Post.create(title: "New Post", body: "This is a new post")
```

This creates a new post and returns the `id` of the newly created record.

## **Updating Records**

You can update existing records by passing the record’s `id` and the fields to update.

```crystal
Post.update(1, title: "Updated Post Title")
```

This updates the post with ID `1` to have the new title "Updated Post Title".

## **Deleting Records**

To delete records, you can use the `delete` method:

```crystal
Post.delete(1)
```

This deletes the post with ID `1`.

## **Associations**

The `Record` module also allows you to define associations between models. In our example, we defined a `belongs_to` relationship in the `Comment` model:

```crystal
belongs_to :post, Post
```

This means that each comment is associated with one post.

You can also define other associations like `has_many` and `has_one`:

```crystal
has_many :comments, Comment
```

This would go into the `Post` model to define that each post can have multiple comments.

---

## Instance-Level Methods for Records

The `Record` module also provides instance-level methods for interacting with individual records:

### **Saving Records**

To insert a new record into the database or update an existing one, you can use the `save` method:

```crystal
post = Post.new("My Title", "My Content")
post.save
```

If the record has an `id`, it will update the record. Otherwise, it will create a new record.

### **Updating Records**

You can also update specific fields on an existing record using the `update` method:

```crystal
post.update(title: "Updated Title")
```

### **Deleting Records**

To delete a record from the database:

```crystal
post.delete
```

This deletes the current record.

### &#x20;**Reloading Records**

You can reload the current state of the record from the database using `reload!`:

```crystal
post.reload!
```

This updates the attributes of the record with the latest values from the database.

### **Working with Attributes**

You can access and manipulate the record’s attributes using the `attributes` method:

```crystal
attrs = post.attributes
# => {id: 1, title: "My Title", body: "My Content"}
```

You can also set the attributes:

```crystal
post.attributes {title: "New Title", body: "Updated Content"}
```

---

## Example: Building a Simple Blog System

Let's combine everything we've learned to build a simple blog system where posts can have many comments.

### **Defining the Schema**:

```crystal
AcmeDB = CQL::Schema.define(
  :acme_db,
  adapter: CQL::Adapter::Postgres,
  uri: "postgresql://example:example@localhost:5432/example"
) do
  table :posts do
    primary
    text :title
    text :body
    timestamp :published_at
  end

  table :comments do
    primary
    bigint :post_id
    text :body
  end
end
```

### **Defining the Models**:

```crystal
struct Post < CQL::Record(Int64)
  db_context AcmeDB, :posts

  getter id : Int64?
  getter title : String
  getter body : String
  getter published_at : Time

  has_many :comments, Comment

  def initialize(@title : String, @body : String, @published_at : Time = Time.utc)
  end
end

struct Comment < CQL::Record(Int64)
  db_context AcmeDB, :comments

  getter id : Int64?
  getter post_id : Int64
  getter body : String

  belongs_to :post, Post

  def initialize(@post_id : Int64, @body : String)
  end
end
```

### **Using the Models**:

- **Creating a Post**:

```crystal
post = Post.new("My First Blog Post", "This is the content of my first blog post.")
post.save
```

- **Adding Comments to the Post**:

```crystal
comment = Comment.new(post.id.not_nil!, "This is a comment.")
comment.save
```

- **Fetching Comments for a Post**:

```crystal
post = Post.find(1)
comments = post.comments
```

---

## Conclusion

The `CQL::Record` module provides powerful tools for working with database records in a Crystal application. It simplifies the process of defining models, querying records, and managing associations. By leveraging the capabilities of CQL's Active Record-style ORM, you can build complex applications with ease.

With `CQL::Record`, you have access to:

- Easy schema and model definition.
- A rich set of query and manipulation methods.
- Powerful association handling (`belongs_to`, `has_many`,
