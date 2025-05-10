---
description: >-
---

# Query Scopes

Query scopes in CQL Active Record allow you to define reusable query constraints as class methods or macros on your models. They help in making your code D.R.Y. (Don't Repeat Yourself) by encapsulating common query logic, leading to more readable and maintainable model and controller code.

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

In CQL, scopes are typically defined using class methods on your model that return a `CQL::Query` object or, more commonly for chainability within the Active Record pattern, a `ChainableQuery(YourModel)` instance.

The `Queryable` module, when included in your model, provides methods like `where`, `order`, etc., that return `ChainableQuery(YourModel)` instances. These are ideal for defining scopes.

**Example: Basic Scopes**

```crystal
struct Article < CQL::ActiveRecord::Model(Int64)
  db_context AcmeDB, :articles

  property id : Int64?
  property title : String
  property status : String # e.g., "draft", "published", "archived"
  property view_count : Int32 = 0
  property published_at : Time?

  # Scope for published articles, ordered by most recent
  def self.published
    where(status: "published").order(published_at: :desc)
  end

  # Scope for draft articles
  def self.drafts
    where(status: "draft")
  end

  # Scope for articles that are archived
  def self.archived
    where(status: "archived")
  end
end
```

In this example:

- `Article.published` will return a `ChainableQuery(Article)` pre-configured to find articles where `status` is "published" and order them.
- These methods leverage the class methods (`where`, `order`) provided by `Queryable` which themselves return `ChainableQuery` instances.

### Scopes with Arguments

Scopes can also accept arguments to make them more flexible.

```crystal
struct Post < CQL::ActiveRecord::Model(Int64)
  db_context AcmeDB, :posts
  # ... properties ...
  property created_at : Time
  property category : String

  # Scope for posts created after a certain date
  def self.created_after(date : Time)
    where("created_at > ?", date)
  end

  # Scope for posts in a specific category
  def self.in_category(category_name : String)
    where(category: category_name)
  end

  # Scope for limiting results
  def self.limit(count : Int32)
    # Note: This reuses the .limit method from Queryable, which is fine.
    # If there were a name collision, you might need to qualify (e.g., self.class.limit(count))
    # or access the underlying query: query.limit(count)
    super(count) # Calls the .limit method from Queryable mixed into the class
  end
end
```

### Scopes Returning `CQL::Query`

While returning `ChainableQuery(YourModel)` is common for seamless chaining with other Active Record query methods, a scope can also return a raw `CQL::Query` object. This might be useful for more complex query constructions that don't neatly fit the `ChainableQuery` API directly, or if you intend to pass the query object to a part of the system that expects `CQL::Query`.

```crystal
struct Product < CQL::ActiveRecord::Model(Int64)
  db_context AcmeDB, :products
  # ... properties ...

  # Scope returning a raw CQL::Query
  def self.low_stock(threshold : Int32)
    # Model.query returns a base CQL::Query for this model
    query.where("stock_count < ?", threshold)
  end
end
```

When a scope returns a `CQL::Query`, you'd typically terminate it with methods like `.all(Product)` or `.first(Product)` that explicitly take the model type for parsing.

---

## Using Scopes

Once defined, scopes can be called like any other class method on the model.

```crystal
# Using scopes defined on Article model
published_articles = Article.published.all
puts "#{published_articles.size} published articles:"
published_articles.each { |a| puts "- #{a.title}" }

# Using scopes with arguments
recent_posts = Post.created_after(7.days.ago).in_category("Crystal Lang").limit(5).all
puts "\n#{recent_posts.size} recent Crystal Lang posts:"
recent_posts.each { |p| puts "- #{p.title}" }

# Using a scope that returns CQL::Query
low_stock_products = Product.low_stock(10).all(Product)
puts "\n#{low_stock_products.size} products with low stock:"
low_stock_products.each { |p| puts "- #{p.name}" }
```

### Chaining Scopes

Scopes that return `ChainableQuery(YourModel)` are designed to be chainable with each other and with other standard query methods from the `Queryable` module (`.where`, `.order`, `.limit`, etc.).

```crystal
# Chaining scopes on Article model
highly_viewed_published_articles = Article.published
  .where("view_count > ?", 1000)
  .order(view_count: :desc)
  .limit(10)
  .all

highly_viewed_published_articles.each do |article|
  puts "Popular: #{article.title} (Views: #{article.view_count})"
end

# Chaining scopes with arguments
featured_tech_posts = Post.in_category("Technology")
  .created_after(1.month.ago)
  .limit(3)
  .order(comments_count: :desc) # Assuming a comments_count property
  .all
```

The `ChainableQuery` class often uses `forward_missing_to Target` (where `Target` is your model class). This allows class methods on your model (like scopes) to be called directly on a `ChainableQuery` instance, making the chaining very natural.

---

## `scope` Macro (If Available)

Some ORMs provide a dedicated `scope` macro for defining scopes more concisely, often handling the lambda creation implicitly. The examples above use standard class methods, which are fully supported and clear in Crystal.

The `README.md` in the main guide shows an example using a `scope` macro:

```crystal
# From README.md example
# struct Article < CQL::ActiveRecord::Model(Int64)
#   scope :published, ->{ query.where(status: "published").order(published_at: :desc) }
#   scope :recent, ->(limit : Int = 5) { published.limit(limit) }
# end
```

If CQL provides such a `scope` macro, it would likely expand to create a class method similar to those shown above. The key is that the proc passed to the `scope` macro should return a `CQL::Query` or `ChainableQuery`.

- **`scope :name, -> { ... query logic ... }`**: Defines a scope without arguments.
- **`scope :name_with_args, ->(arg1 : Type, ...) { ... query logic ... }`**: Defines a scope that accepts arguments.

Consult the specific CQL version documentation to confirm if a `scope` macro is provided and its exact usage.
If not, defining scopes as class methods that return `ChainableQuery` instances (e.g., `def self.published; where(...); end`) is a robust and standard Crystal approach.

---

Scopes are a powerful feature for organizing your database query logic, making your application easier to read, write, and maintain. They promote the principle of keeping data logic within the model layer.
