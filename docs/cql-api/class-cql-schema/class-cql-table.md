# class Cql::Table

`Reference` < `Object`

Represents a table in the database. This class is responsible for handling table creation, modification, and deletion.

## Usage

```crystal
table = Table.new(:users, schema)
=> #<Table:0x00007f8e7a4e1e80>
```

```crystal
table.column(:id, Int64, primary: true)
table.column(:name, String)
table.create_sql
=> "CREATE TABLE users (id BIGINT PRIMARY KEY, name TEXT);"
```

```crystal
table = Table.new(:users, schema)
table.drop!
=> nil
```

```crystal
table = Table.new(:users, schema)
table.truncate!
=> nil

table = Table.new(:users, schema)
table.column(:id, Int64, primary: true)
table.column(:name, String)
table.create!
=> nil
```

## Constants

### Log

```crystal
::Log.for(self)
```

## Constructors

### def new`(table_name : Symbol, schema : Schema, as_name : String | Nil = nil)`

## Instance Methods

### def add\_index`(columns : Array(Symbol), unique : Bool = false, table : Table = self)`

Adds a new column to the table.

* **@param** columns \[Array(Symbol)] the columns to be indexed
* **@param** unique \[Bool] whether the index should be unique (default: false)
* **@param** table \[Table] the table to add the index to (default: self)
* **@return** \[Index] the new index

**Example** Adding a new index

```crystal
add_index([:email], unique: true)
add_index([:email, :username], unique: true)
add_index([:email, :username], unique: true, table: users)
```

### def as\_name

### def bigint`(name : Symbol, as as_name : String | Nil = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)`

Adds a new column to the table.

* **@param** name \[Symbol] the name of the column to be added
* **@param** as\_name \[String, nil] an optional alias for the column
* **@param** null \[Bool] whether the column allows null values (default: false)
* **@param** default \[DB::Any, nil] the default value for the column (default: nil)
* **@param** unique \[Bool] whether the column should have a unique constraint (default: false)
* **@param** index \[Bool] whether the column should be indexed (default: false)
* **@return** \[Column] the new column

**Example** Adding a new column with default options

```crystal
bigint :age
bigint :age, as: "user_age", null: false, default: 18, unique: true, index: true
```

### def blob`(name : Symbol, as as_name : String | Nil = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, size : Int32 | Nil = nil, index : Bool = false)`

Adds a new column to the table.

* **@param** name \[Symbol] the name of the column to be added
* **@param** as\_name \[String, nil] an optional alias for the column
* **@param** null \[Bool] whether the column allows null values (default: false)
* **@param** default \[DB::Any, nil] the default value for the column (default: nil)
* **@param** unique \[Bool] whether the column should have a unique constraint (default: false)
* **@param** index \[Bool] whether the column should be indexed (default: false)
* **@return** \[Column] the new column

**Example** Adding a new column with default options

```crystal
blob :data
blob :data, as: "binary_data", null: false, default: nil, unique: true, index: true
```

### def boolean`(name : Symbol, as as_name : String | Nil = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)`

Adds a new column to the table.

* **@param** name \[Symbol] the name of the column to be added
* **@param** as\_name \[String, nil] an optional alias for the column
* **@param** null \[Bool] whether the column allows null values (default: false)
* **@param** default \[DB::Any, nil] the default value for the column (default: nil)
* **@param** unique \[Bool] whether the column should have a unique constraint (default: false)
* **@param** index \[Bool] whether the column should be indexed (default: false)
* **@return** \[Column] the new column

**Example** Adding a new column with default options

```crystal
boolean :active
boolean :active, as: "is_active", null: false, default: false, unique: true, index: true
```

### def column`(name : Symbol, type : T.class, as as_name : String | Nil = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, size : Int32 | Nil = nil, index : Bool = false) forall T`

Adds a new column to the table.

* **@param** name \[Symbol] the name of the column to be added
* **@param** type \[T.class] the data type of the column
* **@param** as\_name \[String, nil] an optional alias for the column
* **@param** null \[Bool] whether the column allows null values (default: false)
* **@param** default \[DB::Any, nil] the default value for the column (default: nil)
* **@param** unique \[Bool] whether the column should have a unique constraint (default: false)
* **@param** size \[Int32, nil] the size of the column (default: nil)
* **@param** index \[Bool] whether the column should be indexed (default: false)
* **@return** \[Column] the new column

**Example** Adding a new column with default options

```crystal
column :email, String
```

### def columns

### def create!

Creates the table in the database.

* **@return** \[Nil]

**Example**

```crystal
table = Table.new(:users, schema)
table.column(:id, Int64, primary: true)
table.column(:name, String)
table.create!
=> nil
```

### def create\_sql

Generates the SQL to create the table.

**Example**

```crystal
table = Table.new(:users, schema)
table.column(:id, Int64, primary: true)
table.column(:name, String)
table.create_sql
```

```crystal
=> "CREATE TABLE users (id BIGINT PRIMARY KEY, name TEXT);"
```

### def date`(name : Symbol, as as_name : String | Nil = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)`

Adds a new column to the table.

* **@param** name \[Symbol] the name of the column to be added
* **@param** as\_name \[String, nil] an optional alias for the column
* **@param** null \[Bool] whether the column allows null values (default: false)
* **@param** default \[DB::Any, nil] the default value for the column (default: nil)
* **@param** unique \[Bool] whether the column should have a unique constraint (default: false)
* **@param** index \[Bool] whether the column should be indexed (default: false)
* **@return** \[Column] the new column

**Example** Adding a new column with default options

```crystal
date :birthday
date :birthday, as: "date_of_birth", null: false, default: Time.local, unique: true, index: true
```

### def double`(name : Symbol, as as_name : String | Nil = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)`

Adds a new column to the table.

* **@param** name \[Symbol] the name of the column to be added
* **@param** as\_name \[String, nil] an optional alias for the column
* **@param** null \[Bool] whether the column allows null values (default: false)
* **@param** default \[DB::Any, nil] the default value for the column (default: nil)
* **@param** unique \[Bool] whether the column should have a unique constraint (default: false)
* **@param** index \[Bool] whether the column should be indexed (default: false)
* **@return** \[Column] the new column

**Example** Adding a new column with default options

```crystal
double :age
double :age, as: "user_age", null: false, default: 18.0, unique: true, index: true
```

### def drop!

Drops the table from the database.

* **@return** \[Nil]

**Example**

```crystal
table = Table.new(:users, schema)
table.drop!
=> nil
```

### def drop\_sql

Generates the SQL to drop the table.

* **@return** \[String] the SQL query

**Example**

```crystal
table = Table.new(:users, schema)
table.drop_sql
```

```crystal
=> "DROP TABLE users;"
```

### def expression

Gets table expression for Sql query generation

* **@return** \[Expression::Table] the table expression

**Example**

```crystal
table = Table.new(:users, schema)
table.expression
=> #<Expression::Table:0x00007f8e7a4e1e80>
```

### def float`(name : Symbol, as as_name : String | Nil = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)`

Adds a new column to the table.

* **@param** name \[Symbol] the name of the column to be added
* **@param** as\_name \[String, nil] an optional alias for the column
* **@param** null \[Bool] whether the column allows null values (default: false)
* **@param** default \[DB::Any, nil] the default value for the column (default: nil)
* **@param** unique \[Bool] whether the column should have a unique constraint (default: false)
* **@param** index \[Bool] whether the column should be indexed (default: false)
* **@return** \[Column] the new column

**Example** Adding a new column with default options

```crystal
float :age
float :age, as: "user_age", null: false, default: 18.0, unique: true, index: true
```

### def integer`(name : Symbol, as as_name : String | Nil = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)`

Adds a new column to the table.

* **@param** name \[Symbol] the name of the column to be added
* **@param** as\_name \[String, nil] an optional alias for the column
* **@param** null \[Bool] whether the column allows null values (default: false)
* **@param** default \[DB::Any, nil] the default value for the column (default: nil)
* **@param** unique \[Bool] whether the column should have a unique constraint (default: false)
* **@param** index \[Bool] whether the column should be indexed (default: false)
* **@return** \[Column] the new column

**Example** Adding a new column with default options

```crystal
integer :age
integer :age, as: "user_age", null: false, default: 18, unique: true, index: true
```

### def interval`(name : Symbol, as as_name : String | Nil = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)`

Adds a new column to the table.

* **@param** name \[Symbol] the name of the column to be added
* **@param** as\_name \[String, nil] an optional alias for the column
* **@param** null \[Bool] whether the column allows null values (default: false)
* **@param** default \[DB::Any, nil] the default value for the column (default: nil)
* **@param** unique \[Bool] whether the column should have a unique constraint (default: false)
* **@param** index \[Bool] whether the column should be indexed (default: false)
* **@return** \[Column] the new column

**Example** Adding a new column with default options

```crystal
interval :duration
interval :duration, as: "time_span", null: false, default: Time.local, unique: true, index: true
```

### def primary`(name : Symbol = :id, type : T.class = Int64, auto_increment : Bool = true, as as_name = nil, unique : Bool = true) forall T`

Adds a new column to the table.

* **@param** name \[Symbol] the name of the column to be added
* **@param** type \[Any] the data type of the column
* **@param** auto\_increment \[Bool] whether the column should auto increment (default: true)
* **@param** as\_name \[String, nil] an optional alias for the column
* **@param** unique \[Bool] whether the column should have a unique constraint (default: true)

**Example** Adding a new primary key column

```crystal
primary :id, Int64
primary :id, Int64, auto_increment: false
```

### def table\_name

### def table\_name=`(table_name : Symbol)`

### def text`(name : Symbol, as as_name : String | Nil = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, size : Int32 | Nil = nil, index : Bool = false)`

Adds a new column to the table.

* **@param** name \[Symbol] the name of the column to be added
* **@param** as\_name \[String, nil] an optional alias for the column
* **@param** null \[Bool] whether the column allows null values (default: false)
* **@param** default \[DB::Any, nil] the default value for the column (default: nil)
* **@param** unique \[Bool] whether the column should have a unique constraint (default: false)
* **@param** index \[Bool] whether the column should be indexed (default: false)
* **@return** \[Column] the new column

**Example** Adding a new column with default options

```crystal
decimal :price
decimal :price, as: "product_price", null: false, default: 0.0, unique: true, index: true
```

### def timestamp`(name : Symbol, as as_name : String | Nil = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)`

Adds a new column to the table.

* **@param** name \[Symbol] the name of the column to be added
* **@param** as\_name \[String, nil] an optional alias for the column
* **@param** null \[Bool] whether the column allows null values (default: false)
* **@param** default \[DB::Any, nil] the default value for the column (default: nil)
* **@param** unique \[Bool] whether the column should have a unique constraint (default: false)
* **@param** index \[Bool] whether the column should be indexed (default: false)
* **@return** \[Column] the new column

**Example** Adding a new column with default options

```crystal
timestamp :created_at
timestamp :created_at, as: "created_at", null: false, default: Time.local, unique: true, index: true
```

### def timestamps

Adds a new column to the table.

**Example** Adding timestamps to the table

```crystal
timestamps
```

### def truncate!

Truncates the table in the database.

* **@return** \[Nil]

**Example**

```crystal
table = Table.new(:users, schema)
table.truncate!
=> nil
```

### def truncate\_sql

Generates the SQL to truncate the table.

* **@return** \[String] the SQL query

**Example**

```crystal
table = Table.new(:users, schema)
table.truncate_sql
=> "TRUNCATE TABLE users;"
```

## Macros

### macro method\_missing`(call)`
