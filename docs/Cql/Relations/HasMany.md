---
title: "Cql::Relations::HasMany"
---

# module Cql::Relations::HasMany

Define the has_many association module that will be included in the model
to define a one-to-many relationship between two tables in the database
and provide methods to manage the association between the two tables and
query records in the associated table based on the foreign key value of
the parent record.

- **param** : name (Symbol) - The name of the association
- **param** : type (Cql::Model) - The target model
- **param** : foreign_key (Symbol) - The foreign key column in the target table
- **return** : Nil

**Example**

```crystal
class User
  include Cql::Model(User, Int64)
  property id : Int64
  property name : String
  has_many :posts, Post, foreign_key: :user_id
end
```

details Table of Contents
[[toc]]

## Macros

### macro has_many`(name, type, foreign_key, cascade = false)`
