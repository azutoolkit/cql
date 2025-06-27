---
description: >-
---

# Query Scopes

Query scopes in CQL Active Record allow you to define reusable query constraints on your models. They help in making your code D.R.Y. (Don't Repeat Yourself) by encapsulating common query logic, leading to more readable and maintainable model and controller code.

The primary way to define scopes in CQL is by using the `scope` macro. Alternatively, scopes can also be defined as class methods.

---

## What are Scopes?

Often, you'll find yourself writing the same query conditions repeatedly. For example:

- Fetching all published articles.
- Finding all active users.
- Retrieving items created in the last 7 days.

Scopes let you give names to these common queries. A scope is essentially a pre-defined query or a piece of a query that can be easily applied and chained.

**Benefits of using scopes:**

- **Readability**: `Article.published.all` is much clearer than `Article.query.where(status: "published").order(published_at: :desc).all(Article)` scattered throughout your codebase.
- **Reusability**: Define the logic once and use it anywhere you need that specific dataset.
- **Maintainability**: If the definition of "published" changes, you only need to update it in one place (the scope definition).
- **Chainability**: Scopes can be chained with other scopes or standard query methods.

---

## Defining Scopes

There are two main ways to define scopes in CQL: using the `scope` macro (recommended) or defining them as class methods.

### 1. Using the `scope` Macro (Recommended)

The most concise and recommended way to define scopes is by using the `scope` macro. This macro is provided by the `CQL::ActiveRecord::Scopes` module, which you should include in your model.

**Syntax:**

`scope :scope_name, ->(optional_arguments) { query_logic }`

- `:scope_name`: The name of the scope (a `Symbol`), which will become a class method on your model.
- `->(optional_arguments) { ... }`: A proc that defines the query logic.
  - It can optionally take arguments with their types, e.g., `->(count : Int32, category : String) { ... }`.
  - Inside the proc, you use standard CQL query methods like `where`, `order`, `limit`, etc. These methods are called on the current query context, which is typically a `ChainableQuery(YourModel)` instance or the model class itself if starting a new chain.
  - The proc should return a `CQL::Query` or a `ChainableQuery(YourModel)`. If a raw `CQL::Query` is returned (e.g., by starting with `query.where(...)`), the `scope` macro intelligently wraps it in a `ChainableQuery(YourModel)` to ensure it remains chainable with other scopes or Active Record query methods.

**Examples:**

```crystal
struct Article
  includes CQL::ActiveRecord::Model(Int64)
  includes CQL::ActiveRecord::Scopes # Important: Include the Scopes module
  db_context AcmeDB, :articles

  property id : Int64?
  property title : String
  property status : String # e.g., "draft", "published", "archived"
  property view_count : Int32 = 0
  property published_at : Time?

  # Scope for published articles, ordered by most recent
  scope :published, ->{ where(status: "published").order(published_at: :desc) }

  # Scope for draft articles
  scope :drafts, ->{ where(status: "draft") }
end

struct Post
  includes CQL::ActiveRecord::Model(Int64)
  includes CQL::ActiveRecord::Scopes # Important: Include the Scopes module
  db_context AcmeDB, :posts

  property created_at : Time
  property category : String
  property comment_count : Int32 = 0

  # Scope for posts created after a certain date
  scope :created_after, ->(date : Time) { where("created_at > ?", date) }

  # Scope for posts in a specific category
  scope :in_category, ->(category_name : String) { where(category: category_name) }

  # Scope for limiting results (calls 'limit' on the current query chain)
  scope :limited, ->(count : Int32) { limit(count) }

  # Scope combining other scopes/query methods
  scope :recent_in_category, ->(category_name : String, count : Int32 = 5) {
    in_category(category_name).created_after(1.week.ago).limited(count).order(comment_count: :desc)
  }
end
```

Using these scopes:

- `Article.published` returns a `ChainableQuery(Article)`.
- `Post.created_after(7.days.ago)` returns a `ChainableQuery(Post)`.

The `scope` macro generates a class method. For example, `scope :published, ->{ where(status: "published") }` on `Article` is roughly equivalent to:

```crystal
# def self.published
#   # Proc is called, self inside proc refers to the current query object or class
#   scope_call_result = (->{ where(status: "published") }).call
#
#   if scope_call_result.is_a?(CQL::Query)
#     ChainableQuery(Article).new(scope_call_result)
#   else
#     scope_call_result # Assumed to be ChainableQuery(Article)
#   end
# end
```

This keeps your model definitions clean and focused on the query logic.

### 2. Defining Scopes with Class Methods (Alternative)

Alternatively, you can define scopes by creating class methods directly. This approach might be preferred for very complex logic that is hard to express in a single proc or if you prefer the explicitness of a full method definition.

When defining scopes as class methods, they should generally return a `ChainableQuery(YourModel)` instance to maintain chainability. The `Queryable` module (included via `CQL::ActiveRecord::Model`) provides methods like `where`, `order`, etc., that return `ChainableQuery(YourModel)` instances and can be used here.

**Example: Basic Scopes as Class Methods**

```crystal
struct Article
  includes CQL::ActiveRecord::Model(Int64)
  # CQL::ActiveRecord::Scopes module is not strictly needed if only using class methods for scopes
  db_context AcmeDB, :articles

  property id : Int64?
  property title : String
  property status : String
  property published_at : Time?

  def self.published
    where(status: "published").order(published_at: :desc)
  end

  def self.drafts
    where(status: "draft")
  end
end
```

**Example: Scopes with Arguments as Class Methods**

```crystal
struct Post
  includes CQL::ActiveRecord::Model(Int64)
  db_context AcmeDB, :posts

  property created_at : Time
  property category : String

  def self.created_after(date : Time)
    where("created_at > ?", date)
  end

  def self.in_category(category_name : String)
    where(category: category_name)
  end

  # Note: If you name a class method scope 'limit', it might hide the
  # underlying Queryable#limit if not handled carefully. Using a different name like 'take'
  # or being explicit (e.g. self.class.query.limit(c)) might be clearer in some cases.
  def self.take(count : Int32)
    limit(count) # Calls Queryable.limit available to the class
  end
end
```

### Scopes Returning `CQL::Query` (Less Common for Chaining)

While `ChainableQuery(YourModel)` is preferred for easy chaining (and is what the `scope` macro ensures), a class method scope _can_ return a raw `CQL::Query` object. This is less common if you want to chain with other Active Record-style methods but might be useful for specific scenarios where you intend to pass the query object to a system expecting a base `CQL::Query`.

```crystal
struct Product
  includes CQL::ActiveRecord::Model(Int64)
  db_context AcmeDB, :products
  property name : String?
  property stock_count : Int32 = 0

  # Scope returning a raw CQL::Query
  def self.low_stock(threshold : Int32)
    query.where("stock_count < ?", threshold) # Model.query returns a base CQL::Query
  end
end
```

When a scope returns `CQL::Query`, terminate it with methods like `.all(Product)` or `.first(Product)`.

---

## Using Scopes

Once defined (via macro or class method), scopes are called like any other class method:

```crystal
# Using macro-defined scopes on Article model
published_articles = Article.published.all
puts "#{published_articles.size} published articles found."

# Using macro-defined scopes with arguments on Post model
recent_crystal_posts = Post.in_category("Crystal Lang").created_after(7.days.ago).limited(5).all
puts "#{recent_crystal_posts.size} recent Crystal Lang posts found."

# Using a class-method scope returning CQL::Query on Product model
low_stock_items = Product.low_stock(10).all(Product)
puts "#{low_stock_items.size} products with low stock."
```

### Chaining Scopes

Scopes returning `ChainableQuery(YourModel)` are designed for chaining with each other and standard query methods (`.where`, `.order`, etc.):

```crystal
# Chaining scopes on Article model
highly_viewed_published_articles = Article.published
  .where("view_count > ?", 1000)
  .order(view_count: :desc)
  .limited(10) # Assuming a 'limited' scope or direct .limit call
  .all

# Chaining scopes on Post model
featured_tech_posts = Post.in_category("Technology")
  .created_after(1.month.ago)
  .limited(3)
  .order(comment_count: :desc)
  .all
```

The `ChainableQuery` class often uses `forward_missing_to Target` (where `Target` is your model class). This allows class methods on your model (including those generated by the `scope` macro or defined manually) to be called on a `ChainableQuery` instance, enabling natural chaining like `Article.where(...).published`.

---

Scopes are a powerful feature for organizing your database query logic, making your application easier to read, write, and maintain. They promote the principle of keeping data logic within the model layer.
