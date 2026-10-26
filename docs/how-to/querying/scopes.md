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

`scope` defines a class method (`Post.published`) and a `QueryBuilder` method, so scopes chain with each other and with `where`, `order` and `limit`. The body runs on the query it is chained to, as if written there: call the builder's methods (`where`, `order`, ...) in it. A body that starts its own query (`Post.query...`) replaces the chain, and a bare `query` is the chain's `CQL::Query`, which `query.where` changes in place. Lambdas have no default values: pass every argument, with the exact type (integer literals are `Int32`).

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
Post.where(user_id: user.id!).published.all # ... WHERE (posts.user_id = ?) AND (posts.published = ?)
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
Post.defined_scopes.keys  # => ["published", "draft", "popular", "recent", ...]
CQL::ActiveRecord::Scopes::ScopeUtilities.scope_defined?(Post, "published") # => true
```

Each model's queries run that model's own scopes, so two models can define scopes with the same name.

## See Also

- [Filter with Where Clauses](filter-records.md)
- [Write Typed Queries](typed-where-dsl.md)
- [Build Complex Queries](complex-queries.md)
- [Paginate Results](pagination.md)
