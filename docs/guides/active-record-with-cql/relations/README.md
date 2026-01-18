# Relationships in CQL Active Record

CQL Active Record provides powerful association functionality that enables you to define and work with relationships between models. The relationship system supports lazy loading, eager loading, and provides a comprehensive API for creating, querying, and manipulating associated records.

## Supported Association Types

CQL supports four main types of associations, each providing a rich set of methods for working with related data:

### 1. `belongs_to`

Defines a one-to-one association where the current model contains the foreign key. Used when a record belongs to another record.

**Example**: A Post belongs to a User

```crystal
class Post
  include CQL::ActiveRecord::Model(Int32)

  property user_id : Int32?
  belongs_to :user, User, :user_id, optional: true, cache: true
end
```

### 2. `has_one`

Defines a one-to-one association where the other model contains the foreign key. Used when a record has exactly one of another record.

**Example**: A User has one Profile

```crystal
class User
  include CQL::ActiveRecord::Model(Int32)

  has_one :profile, UserProfile, foreign_key: :user_id, dependent: :destroy
end
```

### 3. `has_many`

Defines a one-to-many association where the other model contains the foreign key. Used when a record can have multiple associated records.

**Example**: A User has many Posts

```crystal
class User
  include CQL::ActiveRecord::Model(Int32)

  has_many :posts, Post, foreign_key: :user_id, dependent: :destroy
end
```

### 4. `many_to_many`

Defines a many-to-many association using a join table. Used when records can have multiple associations on both sides.

**Example**: Movies and Actors (many-to-many)

```crystal
class Movie
  include CQL::ActiveRecord::Model(Int32)

  many_to_many :actors, Actor, join_through: :movies_actor, dependent: :destroy
end

class Actor
  include CQL::ActiveRecord::Model(Int32)

  many_to_many :movies, Movie, join_through: :movies_actor
end
```

## Association Features

### Lazy Loading

Associations are loaded on-demand when first accessed, optimizing performance by only fetching data when needed.

### Memoization

Once loaded, associations are cached for the lifetime of the object instance, preventing unnecessary database queries.

### Collection Methods

`has_many` and `many_to_many` associations return collection objects that provide methods for:

- Creating new associated records
- Finding records by attributes
- Checking existence
- Counting records
- Clearing associations
- Reloading data

### Dependent Options

Control what happens to associated records when the parent is destroyed:

- `:destroy` - Destroy associated records
- `:delete` - Delete associated records without callbacks
- `nil` - Leave associated records orphaned (default)

### Optional Associations

Mark associations as optional when the foreign key can be nil:

```crystal
belongs_to :user, User, :user_id, optional: true
```

### Caching

Enable association caching to improve performance:

```crystal
belongs_to :user, User, :user_id, cache: true
```

## Association API Methods

### For `belongs_to` associations:

- `record.association` - Get the associated record
- `record.association=` - Set the associated record
- `record.build_association` - Build a new associated record
- `record.create_association` - Create and save a new associated record
- `record.update_association` - Update the associated record
- `record.delete_association` - Remove the association (set foreign key to nil)

### For `has_one` associations:

- `record.association` - Get the associated record
- `record.association=` - Set the associated record
- `record.build_association` - Build a new associated record
- `record.create_association` - Create and save a new associated record
- `record.update_association` - Update the associated record
- `record.delete_association` - Delete the associated record

### For `has_many` and `many_to_many` associations:

- `record.associations` - Get the association collection
- `record.associations.create` - Create a new associated record
- `record.associations.find` - Find records by attributes
- `record.associations.exists?` - Check if records exist
- `record.associations.size` - Count associated records
- `record.associations.clear` - Remove all associations
- `record.associations.delete` - Remove specific records
- `record.associations.reload` - Reload the collection from database
- `record.associations.ids` - Get array of associated record IDs
- `record.associations.ids=` - Set associations by IDs
- `record.reload_associations` - Reload and get new collection instance

## Relationship Guides

Detailed guides for each association type with complete examples:

- [Belongs To](./belongsto.md): One-to-one relationships where this model has the foreign key
- [Has One](./hasone.md): One-to-one relationships where the other model has the foreign key
- [Has Many](./hasmany.md): One-to-many relationships for collections of associated records
- [Many To Many](./manytomany.md): Many-to-many relationships using join tables

Each guide includes:

- **Schema and Model Setup**: How to define tables and relationships
- **Basic Usage**: Creating and accessing associations
- **Advanced Features**: Using collection methods, dependent options, and performance optimizations
- **Complete Examples**: Real-world scenarios with full code samples

## Eager Loading with Preload

CQL provides the `preload` method to efficiently load associations and avoid N+1 query problems:

```crystal
# Load users with their posts in 2 queries (instead of N+1)
users = User.preload(:posts).all
users.each do |user|
  puts "#{user.name} has #{user.posts.size} posts"  # No additional query
end

# Preload multiple associations
users = User.preload(:posts, :comments, :profile).all

# Chain with other query methods
active_users = User.where(active: true)
                   .preload(:posts)
                   .order(:name)
                   .all
```

For more details, see:

- [Eager Loading in Queryable](../queryable.md#eager-loading-with-preload)
- [HasMany Eager Loading](./hasmany.md#eager-loading)

## Best Practices

### Performance

- Use `cache: true` for frequently accessed `belongs_to` associations
- Use `preload` to avoid N+1 queries when accessing associations in loops
- Use `dependent: :destroy` or `:delete` to maintain referential integrity

### Schema Design

- Follow naming conventions (singular for `belongs_to`/`has_one`, plural for `has_many`/`many_to_many`)
- Use appropriate foreign key column names (e.g., `user_id` for a User association)
- Create proper database indexes on foreign key columns

### Code Organization

- Define associations after properties but before validations
- Group related associations together
- Use descriptive association names that reflect the business relationship

---

The CQL association system provides a powerful, type-safe way to work with related data while maintaining excellent performance through lazy loading and intelligent caching.
