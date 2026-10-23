# Create Query Scopes

This guide shows you how to create reusable query scopes for common filtering patterns.

## Define a Scope

Use the `scope` macro with a lambda that returns a query:

```crystal
struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :posts

  property id : Int64?
  property title : String
  property published : Bool = false
  property views_count : Int64 = 0
  property created_at : Time?

  # Scopes
  scope :published, -> { where(published: true) }
  scope :draft, -> { where(published: false) }
  scope :popular, ->(min_views : Int32) { where { views_count >= min_views } }
  scope :recent, ->(days : Int32) { where { created_at > days.days.ago } }
end
```

`scope` defines a class method (`Post.published`) and a method on the query builder, so scopes chain with each other and with `where`, `order`, `limit` and the rest. Crystal lambdas have no default argument values, so pass every argument, and use the exact argument type (integer literals are `Int32`).

## Use Scopes

```crystal
# Single scope
Post.published.all

# Chain scopes
Post.published.popular(100).recent(7).all

# With other methods
Post.published.order(created_at: :desc).limit(10).all
```

## Scope with Parameters

```crystal
struct User
  scope :by_role, ->(role : String) { where(role: role) }
  scope :created_after, ->(date : Time) { where { created_at > date } }
  scope :age_between, ->(min : Int32, max : Int32) { where { age.between(min, max) } }
end

# Usage
User.by_role("admin").all
User.created_after(1.month.ago).all
User.age_between(18, 65).all
```

## Conditional Scopes

A scope must return a query, so apply conditions in your calling code, or return an unfiltered `query` from a plain class method:

```crystal
struct Post
  def self.published_if(condition : Bool)
    condition ? published : query
  end
end

# Usage - only filter if condition is true
show_published = params["published"]? == "true"
Post.published_if(show_published).all
```

Plain class methods like this work as the first call in a chain (`Post.published_if(true).order(...)`) but cannot be chained after other query methods; use `scope` for that.

## Default Scope Pattern

Create a scope for commonly used conditions:

```crystal
struct Post
  scope :active, -> { where { deleted_at == nil }.where(published: true) }
end

# Always start queries from active scope
Post.active.order(created_at: :desc).all
```

## Scope Chaining

Scopes can be chained in any order:

```crystal
# All these work
Post.published.popular(100).recent(7).all
Post.recent(7).published.popular(100).all
Post.popular(100).published.all
```

## Scope with Ordering

```crystal
struct Post
  scope :newest_first, -> { order(created_at: :desc) }
  scope :most_popular, -> { order(views_count: :desc) }
end

Post.published.newest_first.limit(10).all
Post.published.most_popular.limit(10).all
```

## Complex Scopes

```crystal
struct Post
  scope :featured, -> {
    where(published: true)
      .where { views_count > 1000 }
      .order(views_count: :desc)
  }

  scope :by_author, ->(user_id : Int64) { where(user_id: user_id) }
  scope :in_category, ->(category_id : Int64) { where(category_id: category_id) }
end

# Usage
Post.featured.limit(5).all
Post.by_author(current_user.id!).published.all
Post.in_category(tech_category.id!).recent(7).all
```

## Scope in Related Queries

`user.posts` is a `Collection`, which does not know your scopes. Start from the model and filter on the foreign key instead:

```crystal
user = User.find!(1)

# Use scopes on associated records
Post.where(user_id: user.id!).published.all
Post.where(user_id: user.id!).recent(30).popular(50).all
```

## Inspect Scopes

```crystal
Post.defined_scopes.keys   # => ["published", "draft", "popular", "recent", ...]
```

Scope names are also registered as methods on the shared query builder, so give scopes distinct names across models (for example `published` on only one model, or `post_published`) when you chain them.

## Verify Scopes Work

```crystal
Post.create!(title: "Draft", body: "...", published: false, views_count: 10)
Post.create!(title: "Published", body: "...", published: true, views_count: 200)
Post.create!(title: "Popular", body: "...", published: true, views_count: 500)

Post.published.count         # => 2
Post.draft.count             # => 1
Post.popular(100).count  # => 2
Post.popular(300).count  # => 1
```

## Related

- [Filter with Where Clauses](filter-records.md)
- [Build Complex Queries](complex-queries.md)
- [Paginate Results](pagination.md)
