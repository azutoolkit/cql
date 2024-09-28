# module CQL::Relations

The `CQL::Relations` module provides utilities for managing relationships between tables in a database schema. It allows you to define associations such as `has_many`, `belongs_to`, and `many_to_many`, enabling easy navigation and querying of related data.

## Example: Defining Relations

```crystal
struct User < CQL::Record(Int64)
  has_many :posts
end

struct Post < CQL::Record(Int64)
  belongs_to :user
end
```

## Methods

### has\_many(relation\_name : Symbol)

Defines a `has_many` relationship between the current model and another.

* **@param** relation\_name \[Symbol] The name of the related model.
* **@return** \[Nil]

**Example**:

```crystal
has_many :posts
```

### belongs\_to(relation\_name : Symbol)

Defines a `belongs_to` relationship between the current model and another.

* **@param** relation\_name \[Symbol] The name of the related model.
* **@return** \[Nil]

**Example**:

```crystal
belongs_to :user
```

### many\_to\_many(relation\_name : Symbol, through : Symbol)

Defines a `many_to_many` relationship between two models through a join table.

* **@param** relation\_name \[Symbol] The name of the related model.
* **@param** through \[Symbol] The name of the join table.
* **@return** \[Nil]

**Example**:

```crystal
many_to_many :tags, through: :posts_tags
```
