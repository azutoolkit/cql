---
description: "Name reusable query fragments on a model with scope, then chain them like any query method."
---

# Create Query Scopes

## Define Scopes

```crystal
class Post
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :posts

  property title : String = ""
  property user_id : Int64?
  property published : Bool = false
  property views_count : Int64 = 0
  property deleted_at : Time?
  property created_at : Time?

  scope :published, -> { where(published: true) }
  scope :draft, -> { where(published: false) }
  scope :popular, ->(min_views : Int32) { where { views_count >= min_views } }
  scope :recent, ->(days : Int32) { where { created_at > days.days.ago } }
  scope :by_author, ->(user_id : Int64) { where(user_id: user_id) }
  scope :newest_first, -> { order(created_at: :desc) }
  scope :featured, -> { where(published: true).where { views_count > 1000 }.order(views_count: :desc) }
  scope :active, -> { where { deleted_at == nil }.where(published: true) } # a "default" to start from
end
```

`scope` defines a class method (`Post.published`) and a `QueryBuilder` method, so scopes chain with each other and with `where`, `order` and `limit`. Lambdas have no default values: pass every argument, with the exact type (integer literals are `Int32`).

## Use Scopes

```crystal
Post.published.count                      # SELECT COUNT(*) FROM posts WHERE posts.published = ?
Post.popular(100).count                   # ... WHERE posts.views_count >= ?

Post.published.popular(100).recent(7).all # chain in any order; conditions are ANDed
Post.recent(7).published.popular(100).all
Post.published.newest_first.limit(10).all
Post.featured.limit(5).all                # ... ORDER BY posts.views_count DESC LIMIT ?
Post.active.order(created_at: :desc).all  # ... WHERE (posts.deleted_at IS NULL) AND (posts.published = ?)

# Scopes also follow where, order and limit. user.posts is a Collection without scopes, so start from Post:
Post.where(user_id: user.id!).published.all
Post.by_author(user.id!).draft.count
```

## Choose a Scope at Runtime

```crystal
class Post
  def self.published_if(condition : Bool)
    condition ? published : query # query is the unfiltered QueryBuilder
  end
end

Post.published_if(params["published"]? == "true").order(created_at: :desc).all
```

A plain class method like this starts a chain but cannot follow other query methods; use `scope` for that.

## List a Model's Scopes

```crystal
Post.defined_scopes.keys  # => [":published", ":draft", ":popular", ":recent", ...]
```

{% hint style="warning" %}
Scope methods are added to the `QueryBuilder` class that every model shares, so the last model to define a scope name wins. Give scopes distinct names across models (for example `published` on one model only, or `post_published`).
{% endhint %}

{% hint style="warning" %}
Once the program calls `pluck`, `pick` or `select(:column)` on `Post`, `Post.published.all` is typed `Array(Post) | Array(Post::Row)`, so reading an attribute may not compile. Start with `Post.query.published` to keep `Array(Post)`.
{% endhint %}

{% hint style="info" %}
A scope chained after another query method repeats that query's conditions in its `WHERE` (`(posts.user_id = ?) AND ((posts.user_id = ?) AND (posts.published = ?))`). The rows are the same; the SQL grows with each chained scope.
{% endhint %}

## See Also

- [Filter with Where Clauses](filter-records.md)
- [Write Typed Queries](typed-where-dsl.md)
- [Build Complex Queries](complex-queries.md)
- [Paginate Results](pagination.md)
