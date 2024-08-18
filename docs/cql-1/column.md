---
title: Cql::Column(T)
---

# class Cql::Column(T)

`Cql::BaseColumn` < `Reference` < `Object`

A column in a table This class represents a column in a table It provides methods for setting the column type, default value, and constraints It also provides methods for building expressions

**Example** Creating a new column

```crystal
schema.build do
  table :users do
    column :name, String, null: false, default: "John"
    column :age, Int32, null: false
  end
end
```

details Table of Contents \[\[toc]]

## Constructors

### def new`(name : Symbol, type : T.class, as_name : String | Nil = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, size : Int32 | Nil = nil, index : Index | Nil = nil)`

Create a new column instance

* **@param** : name (Symbol) - The name of the column
* **@param** : type (Any) - The data type of the column
* **@param** : as\_name (String, nil) - An optional alias for the column
* **@param** : null (Bool) - Whether the column allows null values (default: false)
* **@param** : default (DB::Any) - The default value for the column (default: nil)
* **@param** : unique (Bool) - Whether the column should have a unique constraint (default: false)
* **@param** : size (Int32, nil) - The size of the column (default: nil)
* **@param** : index (Index, nil) - The index for the column (default: nil)
* **@return** : Nil
* **@raise** : Cql::Error if the column type is not valid

**Example**

```crystal
column = Cql::Column.new(:name, String)
```

## Instance Methods

### def expression

Expressions for this column

* **@return** \[Expression::ColumnBuilder] the column expression builder

**Example**

```crystal
column = Cql::Column.new(:name, String)
column.expression.eq("John")
```

### def validate!`(value)`

Validate the value

* **@param** value \[DB::Any] The value to validate

**Example**

```crystal
column = Cql::Column.new(:name, String)
column.validate!("John")
```
