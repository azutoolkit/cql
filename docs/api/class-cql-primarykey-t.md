# class CQL::PrimaryKey(T)

`CQL::Column` < `CQL::BaseColumn` < `Reference` < `Object`

The `CQL::PrimaryKey` class defines a primary key column in a database schema.

## Example: Defining a Primary Key

```crystal
schema.table :users do
  primary :id, Int32
  column :name, String
end
```

## Constructors

### def new(name : Symbol = :id, type : PrimaryKeyType = Int64.class, auto\_increment : Bool = true, unique : Bool = true, default : DB::Any = nil)

Initializes a new primary key column.

* **@param** name \[Symbol] The name of the primary key column (default: `:id`).
* **@param** type \[PrimaryKeyType] The data type of the primary key (default: `Int64`).
* **@param** auto\_increment \[Bool] Whether the column is auto-incremented (default: `true`).
* **@param** unique \[Bool] Whether the primary key is unique (default: `true`).
* **@param** default \[DB::Any] The default value for the column.
* **@return** \[PrimaryKey] The primary key object.

## Instance Methods

### def as\_name

Returns the alias name of the primary key, if set.

* **@return** \[String | Nil] The alias name.

### def auto\_increment

Indicates whether the primary key is auto-incremented.

* **@return** \[Bool] `true` if the primary key is auto-incremented, `false` otherwise.
