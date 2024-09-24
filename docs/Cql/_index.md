---
title: "CQL::Index"
---

# class CQL::Index

`Reference` < `Object`

The `CQL::Index` class represents an index on a table. Indexes are used to optimize query performance by providing faster access to data. This class provides methods for defining the columns that make up the index and specifying whether the index is unique.

## Example: Creating an Index

```crystal
schema.define do
  table :users do
    column :name, String
    column :email, String
    index [:name, :email], unique: true
  end
end
```

## Constructors

### def new(table : Table, columns : Array(Symbol), unique : Bool = false)

Creates a new index on the specified table.

- **@param** table \[Table] The table on which the index is created.
- **@param** columns \[Array(Symbol)] The columns that make up the index.
- **@param** unique \[Bool] Whether the index should enforce uniqueness (default: `false`).
- **@return** \[Index] The created index object.

**Example**:

```crystal
index = CQL::Index.new(:users, [:name, :email], unique: true)
```

## Methods

### def unique

Specifies whether the index is unique.

- **@return** \[Bool] `true` if the index is unique, `false` otherwise.

**Example**:

```crystal
index.unique(true)
```

### def generate_name

Generates a name for the index based on the table and columns.

- **@return** \[String] The generated index name.

**Example**:

```crystal
index_name = index.generate_name
```
