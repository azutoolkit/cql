---
title: Cql::Index
---

# class Cql::Index

`Reference` < `Object`

An index on a table This class represents an index on a table It provides methods for setting the columns and unique constraint It also provides methods for generating the index name

**Example** Creating a new index

```crystal
schema.build do
  table :users do
    column :name, String
    column :email, String
    index [:name, :email], unique: true
  end
end
```

details Table of Contents \[\[toc]]

## Constructors

### def new`(table : Table, columns : Array(Symbol), unique : Bool = false, name : String | Nil = nil)`

Create a new index instance on a table

* **@param** : table (Table) - The table to create the index on
* **@param** : columns (Array(Symbol)) - The columns to index
* **@param** : unique (Bool) - Whether the index should be unique (default: false)
* **@param** : name (String, nil) - The name of the index (default: nil)
* **@return** : Nil
* **@raise** : Cql::Error if the table does not exist
* **@raise** : Cql::Error if the column does not exist

**Example**

```crystal
index = Cql::Index.new(table, [:name, :email], unique: true)
```

## Instance Methods

### def columns

### def index\_name

Generate the index name

* **@return** : String
* **@raise** : Nil

**Example**

```crystal
index_name = index.index_name
```

### def name

### def name=`(name : String | Nil)`

### def table

### def unique?
