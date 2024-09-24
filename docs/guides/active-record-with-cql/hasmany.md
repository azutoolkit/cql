# HasMany

## CQL Active Record: `HasMany` Relationship Guide

In this guide, we’ll focus on the `HasMany` relationship using CQL's Active Record syntax. Like the previous `BelongsTo` and `HasOne` relationships, we’ll start with an Entity-Relationship Diagram (ERD) to visually explain how the `HasMany` relationship works and build on our previous schema.

## **What is a `HasMany` Relationship?**

The `HasMany` relationship indicates that one entity (a record) is related to multiple other entities. For example, a **Post** can have many **Comments**. This relationship is a one-to-many mapping between two entities.

### Example Scenario: Posts and Comments

<figure><img src="../../.gitbook/assets/Untitled-2.svg" alt=""><figcaption></figcaption></figure>

In a blogging system:

- A **Post** can have many **Comments**.
- Each **Comment** belongs to one **Post**.

This is a common one-to-many relationship where one post can have multiple comments, but each comment refers to only one post.

---

## Defining the Schema

We’ll define the `posts` and `comments` tables in the schema using CQL’s DSL.

```crystal
AcmeDB = CQL::Schema.db_context(
  :acme_db,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
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

- **posts** table: Stores post details like `title`, `body`, and `published_at`.
- **comments** table: Stores comment details with a foreign key `post_id` that references the `posts` table.

---

## Defining the Models

Let’s db_context the `Post` and `Comment` models and establish the `HasMany` and `BelongsTo` relationships in CQL.

### **Post Model**

```crystal
struct Post < CQL::Record(Post, Int64)
  db_context AcmeDB, :posts

  getter id : Int64?
  getter title : String
  getter body : String
  getter published_at : Time

  # Initializing a new post with title, body, and published_at
  def initialize(@title : String, @body : String, @published_at : Time = Time.utc)
  end

  # Association: A Post has many Comments
  has_many :comments, Comment
end
```

- The `has_many :comments` association in the `Post` model defines that each post can have multiple comments.

### **Comment Model**

```crystal
struct Comment< CQL::Record(Comment, Int64)
  db_context AcmeDB, :comments

  getter id : Int64?
  getter post_id : Int64
  getter body : String

  # Initializing a comment with post_id (foreign key) and body
  def initialize(@post_id : Int64, @body : String)
  end

  # Association: A Comment belongs to one Post
  belongs_to :post, Post
end
```

- The `belongs_to :post` association in the `Comment` model links each comment to a post by using the `post_id` foreign key.

## Creating and Querying Records

Now that we have defined the `Post` and `Comment` models with a `HasMany` and `BelongsTo` relationship, let’s create and query records in CQL.

### **Creating a Post and Comments**

```crystal
# Create a new Post
post = Post.new("My First Blog Post", "This is the content of my first blog post.")
post.save

# Create Comments for the Post
comment1 = Comment.new(post.id.not_nil!, "Great post!")
comment2 = Comment.new(post.id.not_nil!, "Thanks for sharing.")
comment1.save
comment2.save
```

- First, we create a `Post` and save it to the database.
- Then, we create two `Comments` and associate them with the post by passing `post.id` as the `post_id` for each comment.

### **Accessing Comments from the Post**

Once a post has comments, you can retrieve all the comments using the `HasMany` association.

```crystal
# Fetch the post
post = Post.find(1)

# Fetch all associated comments
post.comments.each do |comment|
  puts comment.body
end
```

Here, `post.comments` retrieves all the comments associated with the post, and we loop through them to print each comment’s body.

### **Accessing the Post from a Comment**

You can also retrieve the post associated with a comment using the `BelongsTo` association.

```crystal
# Fetch the comment
comment = Comment.find(1)

# Fetch the associated post
post = comment.post

puts post.title  # Outputs: "My First Blog Post"
```

In this example, `comment.post` fetches the post that the comment belongs to.

---

## Updating and Deleting the Associations

### **Adding a New Comment to an Existing Post**

You can add a new comment to an existing post as follows:

```crystal
# Fetch the post
post = Post.find(1)

# Create a new comment for the post
new_comment = Comment.new(post.id.not_nil!, "Another comment")
new_comment.save
```

### **Deleting a Post and Its Associated Comments**

If you delete a post, you may want to delete all associated comments as well. However, by default, this will not happen unless you specify cascade deletion in your database.

```crystal
# Fetch the post
post = Post.find(1)

# Delete the post
post.delete

# (Optional) Manually delete the associated comments
post.comments.each do |comment|
  comment.delete
end
```

---

## Advanced Querying

You can also perform advanced queries using the `HasMany` relationship. For example, finding posts with a certain number of comments or filtering comments for a post based on specific conditions.

### **Fetching Posts with Comments**

You can load posts along with their comments in one query:

```crystal
posts_with_comments = Post.includes(:comments).all
```

### **Finding Comments for a Specific Post**

If you want to query for specific comments associated with a post, you can filter them as follows:

```crystal
# Fetch the post
post = Post.find(1)

# Find comments with specific condition (e.g., containing the word "Great")
filtered_comments = post.comments.where { body.like("%Great%") }
```

---

## Summary

In this guide, we’ve explored the `HasMany` relationship in CQL. We:

- Defined the `Post` and `Comment` tables in the schema.
- Created corresponding models, specifying the `HasMany` relationship in the `Post` model and the `BelongsTo` relationship in the `Comment` model.
- Demonstrated how to create, query, update, and delete records using the `HasMany` and `BelongsTo` associations.

### Next Steps

In the next guide, we’ll build upon this ERD and cover the `ManyToMany` relationship, which is useful when two entities are associated with many of each other (e.g., a post can have many tags, and a tag can belong to many posts).

Feel free to experiment with the `HasMany` relationship by adding more fields, filtering queries, or extending your schema to handle more complex use cases.
