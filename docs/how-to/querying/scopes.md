# Create Query Scopes

This guide shows you how to create reusable query scopes for common filtering patterns.

## Define a Scope

Add class methods that return query builders:

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
  def self.published
    where(published: true)
  end

  def self.draft
    where(published: false)
  end

  def self.popular(min_views = 100)
    where { views_count >= min_views }
  end

  def self.recent(days = 7)
    where { created_at > days.days.ago }
  end
end
```

## Use Scopes

```crystal
# Single scope
Post.published.all

# Chain scopes
Post.published.popular.recent.all

# With other methods
Post.published.order(created_at: :desc).limit(10).all
```

## Scope with Parameters

```crystal
struct User
  def self.by_role(role : String)
    where(role: role)
  end

  def self.created_after(date : Time)
    where { created_at > date }
  end

  def self.age_between(min : Int32, max : Int32)
    where { age.between(min, max) }
  end
end

# Usage
User.by_role("admin").all
User.created_after(1.month.ago).all
User.age_between(18, 65).all
```

## Conditional Scopes

```crystal
struct Post
  def self.published_if(condition : Bool)
    condition ? published : self
  end
end

# Usage - only filter if condition is true
show_published = params["published"]? == "true"
Post.published_if(show_published).all
```

## Default Scope Pattern

Create a method for commonly used conditions:

```crystal
struct Post
  def self.active
    where(deleted_at: nil).where(published: true)
  end
end

# Always start queries from active scope
Post.active.order(created_at: :desc).all
```

## Scope Chaining

Scopes can be chained in any order:

```crystal
# All these work
Post.published.popular.recent.all
Post.recent.published.popular.all
Post.popular.published.all
```

## Scope with Ordering

```crystal
struct Post
  def self.newest_first
    order(created_at: :desc)
  end

  def self.most_popular
    order(views_count: :desc)
  end
end

Post.published.newest_first.limit(10).all
Post.published.most_popular.limit(10).all
```

## Complex Scopes

```crystal
struct Post
  def self.featured
    published
      .where { views_count > 1000 }
      .order(views_count: :desc)
  end

  def self.by_author(user : User)
    where(user_id: user.id)
  end

  def self.in_category(category : Category)
    where(category_id: category.id)
  end
end

# Usage
Post.featured.limit(5).all
Post.by_author(current_user).published.all
Post.in_category(tech_category).recent.all
```

## Scope in Related Queries

Scopes work with relationships:

```crystal
user = User.find!(1)

# Use scopes on associated records
user.posts.published.all
user.posts.recent(30).popular(50).all
```

## Verify Scopes Work

```crystal
Post.create!(title: "Draft", body: "...", published: false, views_count: 10)
Post.create!(title: "Published", body: "...", published: true, views_count: 200)
Post.create!(title: "Popular", body: "...", published: true, views_count: 500)

Post.published.count       # => 2
Post.draft.count           # => 1
Post.popular(100).count    # => 2
Post.popular(300).count    # => 1
```

## Related

- [Filter with Where Clauses](filter-records.md)
- [Build Complex Queries](complex-queries.md)
- [Paginate Results](pagination.md)
