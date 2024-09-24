---
title: "CQL::PrimaryKeyType"
---

# alias CQL::PrimaryKeyType

The `CQL::PrimaryKeyType` alias represents the type of a primary key column in a database schema. Primary keys can be of various types, such as `Int32`, `Int64`, or other unique identifiers.

## Example: Defining a Primary Key with PrimaryKeyType

```crystal
schema.define do
  table :users do
    primary :id, CQL::PrimaryKeyType
    column :name, String
  end
end
```

### Supported Types

- **Int32**: Represents a 32-bit integer primary key.
- **Int64**: Represents a 64-bit integer primary key.
- **UUID**: Represents a Universally Unique Identifier (if supported by the database).

**Example**:

```crystal
primary :id, Int64, auto_increment: true
```
