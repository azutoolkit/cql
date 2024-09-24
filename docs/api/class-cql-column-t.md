# class CQL::Column(T)

`CQL::BaseColumn` < `Reference` < `Object`

The `CQL::Column` class represents a column in a table. It provides methods for defining the column type, setting default values, and applying constraints such as `NOT NULL` or `UNIQUE`.

## Example: Creating a Column

```crystal
schema.define do
  table :users do
    column :name, String, null: false, default: "John"
    column :age, Int32, null: false
  end
end
```

## Constructors

### def new(name : Symbol, type : Type, options : Hash = {})

Creates a new column with the specified name, type, and options.

* **@param** name \[Symbol] The name of the column.
* **@param** type \[Type] The data type of the column.
* **@param** options \[Hash] Additional options for the column (e.g., `null`, `default`, `unique`).
* **@return** \[Column] The created column object.

**Example**:

```crystal
column = CQL::Column.new(:name, String, null: false, default: "John")
```

## Methods

### def null

Specifies whether the column allows `NULL` values.

* **@return** \[Bool] `true` if the column allows null values, `false` otherwise.

**Example**:

```crystal
column.null(false)
```

### def default(value : DB::Any)

Sets the default value for the column.

* **@param** value \[DB::Any] The default value for the column.
* **@return** \[Column] The updated column object.

**Example**:

```crystal
column.default("John")
```

### def unique

Specifies whether the column should have a `UNIQUE` constraint.

* **@return** \[Column] The updated column object.

**Example**:

```crystal
column.unique(true)
```
