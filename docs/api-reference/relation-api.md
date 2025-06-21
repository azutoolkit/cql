---
description: >-
  Complete API reference for CQL model relationships - association types, configuration, query methods, eager loading, lifecycle, and best practices.
---

# Relation API Reference

This reference documents all association features available in CQL's Active Record implementation.

## Overview

CQL supports defining relationships between models using associations. These enable you to express and query connections between tables in a type-safe, idiomatic way.

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  has_many :posts, Post, foreign_key: :user_id
  has_one :profile, Profile, foreign_key: :user_id
  belongs_to :account, Account, foreign_key: :account_id
  many_to_many :groups, Group, join_table: :groups_users, foreign_key: :user_id, association_foreign_key: :group_id
end
```

## Association Types

### belongs_to

````crystal
belongs_to :association_name, AssociatedModel, foreign_key: :foreign_key, class_name: "ClassName", optional: Bool

# Description
# Defines a many-to-one association. The current model holds the foreign key.

# Options
# - **foreign_key** [Symbol] The foreign key column
# - **class_name** [String] Override the associated class name
# - **optional** [Bool] Allow nil foreign key (default: false)

# Example
# ```crystal
# belongs_to :account, Account, foreign_key: :account_id
# belongs_to :owner, User, class_name: "User", foreign_key: :owner_id, optional: true
# ```
````

### has_one

````crystal
has_one :association_name, AssociatedModel, foreign_key: :foreign_key, class_name: "ClassName"

# Description
# Defines a one-to-one association. The associated model holds the foreign key.

# Options
# - **foreign_key** [Symbol] The foreign key column in the associated model
# - **class_name** [String] Override the associated class name

# Example
# ```crystal
# has_one :profile, Profile, foreign_key: :user_id
# ```
````

### has_many

````crystal
has_many :association_name, AssociatedModel, foreign_key: :foreign_key, class_name: "ClassName"

# Description
# Defines a one-to-many association. The associated model holds the foreign key.

# Options
# - **foreign_key** [Symbol] The foreign key column in the associated model
# - **class_name** [String] Override the associated class name

# Example
# ```crystal
# has_many :posts, Post, foreign_key: :user_id
# ```
````

### many_to_many

````crystal
many_to_many :association_name, AssociatedModel, join_table: :join_table, foreign_key: :foreign_key, association_foreign_key: :association_foreign_key, class_name: "ClassName"

# Description
# Defines a many-to-many association using a join table.

# Options
# - **join_table** [Symbol] The join table name
# - **foreign_key** [Symbol] The foreign key in the join table for the current model
# - **association_foreign_key** [Symbol] The foreign key in the join table for the associated model
# - **class_name** [String] Override the associated class name

# Example
# ```crystal
# many_to_many :groups, Group, join_table: :groups_users, foreign_key: :user_id, association_foreign_key: :group_id
# ```
````

## Association Configuration Options

- **foreign_key**: The column used for the relationship
- **class_name**: Override the default class name for the association
- **join_table**: For many-to-many, the table that joins the two models
- **association_foreign_key**: For many-to-many, the foreign key for the associated model
- **optional**: For belongs_to, allows the foreign key to be nil

## Query Methods for Associations

Associations provide query methods for fetching related records:

```crystal
user = User.find!(1)
user.posts           # => Array(Post)
user.profile         # => Profile?
user.account         # => Account?
user.groups          # => Array(Group)

# Querying through associations
user.posts.where(published: true).order(:created_at)
```

### Association Scopes

You can chain query methods on associations:

```crystal
user.posts.where(published: true).limit(5)
account.users.order(:name)
```

### Eager Loading

To avoid N+1 queries, use eager loading:

```crystal
users = User.includes(:posts, :profile).all

# Now user.posts and user.profile are preloaded
```

### Preloading Multiple Associations

```crystal
users = User.includes(:posts, :profile, :groups).all
```

## Association Lifecycle and Callbacks

Associations can trigger callbacks on related records:

- `after_add` / `after_remove` for has_many and many_to_many
- `before_add` / `before_remove` for has_many and many_to_many

```crystal
has_many :posts, Post, foreign_key: :user_id, after_add: :notify_post_added

private def notify_post_added(post : Post)
  # ...
end
```

## Best Practices

- Use explicit foreign keys for clarity
- Use `includes` to avoid N+1 queries
- Keep association methods private if not needed externally
- Document association options and side effects
- Use callbacks for side effects, not business logic

## Example: Full Association Setup

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  has_many :posts, Post, foreign_key: :user_id, after_add: :notify_post_added
  has_one :profile, Profile, foreign_key: :user_id
  belongs_to :account, Account, foreign_key: :account_id, optional: true
  many_to_many :groups, Group, join_table: :groups_users, foreign_key: :user_id, association_foreign_key: :group_id

  private def notify_post_added(post : Post)
    # ...
  end
end
```

This API reference provides comprehensive documentation for all association functionality in CQL. Use it alongside the guides for practical examples and best practices.
