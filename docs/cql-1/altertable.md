---
title: Cql::AlterTable
---

# class Cql::AlterTable

`Reference` < `Object`

This module is part of the Cql namespace and is responsible for handling database alterations. This class represents an AlterTable object.

**Example** :

```crystal
alter_table = AlterTable.new
alter_table.add_column(:email, "string")
alter_table.drop_column(:age)
alter_table.rename_column(:email, :user_email)
alter_table.change_column(:age, "string")

=> #<AlterTable:0x00007f8e7a4e1e80>
```

details Table of Contents \[\[toc]]

## Constructors

### def new`(table : Cql::Table, schema : Cql::Schema)`

## Instance Methods

### def add\_column`(name : Symbol, type : Any, as as_name : String | Nil = nil, null : Bool = true, default : DB::Any = nil, unique : Bool = false, size : Int32 | Nil = nil, index : Bool = false)`

Adds a new column to the table.

* **@param** name \[Symbol] the name of the column to be added
* **@param** type \[Any] the data type of the column
* **@param** as\_name \[String, nil] an optional alias for the column
* **@param** null \[Bool] whether the column allows null values (default: true)
* **@param** default \[DB::Any, nil] the default value for the column (default: nil)
* **@param** unique \[Bool] whether the column should have a unique constraint (default: false)
* **@param** size \[Int32, nil] the size of the column (default: nil)
* **@param** index \[Bool] whether the column should be indexed (default: false)

**Example** Adding a new column with default options

```crystal
add_column(:email, "string")
```

**Example** Adding a new column with custom options

```crystal
add_column(:age, "integer", null: false, default: "18")
```

### def change\_column`(name : Symbol, type : Any)`

Changes the type of a column in the table.

* **@param** name \[Symbol] the name of the column to be changed
* **@param** type \[Any] the new data type for the column

**Example** Changing the type of a column

```crystal
change_column(:age, "string")
```

### def create\_index`(name : Symbol, columns : Array(Symbol), unique : Bool = false)`

Creates an index on the table.

* **@param** name \[Symbol] the name of the index
* **@param** columns \[Array(Symbol)] the columns to be indexed
* **@param** unique \[Bool] whether the index should be unique (default: false)

**Example** Creating an index

```crystal
create_index(:index_users_on_email, [:email], unique: true)
```

### def drop\_column`(column : Symbol)`

Drops a column from the table.

* **@param** column \[Symbol] the name of the column to be dropped

**Example** Dropping a column

```crystal
drop_column(:age)
```

### def drop\_foreign\_key`(name : Symbol)`

Drops a foreign key from the table.

* **@param** name \[Symbol] the name of the foreign key to be dropped

**Example** Dropping a foreign key

```crystal
drop_foreign_key(:fk_user_id)
```

### def drop\_index`(name : Symbol)`

Drops an index from the table.

* **@param** name \[Symbol] the name of the index to be dropped

**Example** Dropping an index

```crystal
drop_index(:index_users_on_email)
```

### def foreign\_key`(name : Symbol, columns : Array(Symbol), table : Symbol, references : Array(Symbol), on_delete : String = "NO ACTION", on_update : String = "NO ACTION")`

Adds a foreign key to the table.

* **@param** name \[Symbol] the name of the foreign key
* **@param** columns \[Array(Symbol)] the columns in the current table
* **@param** table \[Symbol] the referenced table
* **@param** references \[Array(Symbol)] the columns in the referenced table
* **@param** on\_delete \[String] the action on delete (default: "NO ACTION")
* **@param** on\_update \[String] the action on update (default: "NO ACTION")

**Example** Adding a foreign key

```crystal
foreign_key(:fk_user_id, [:user_id], :users, [:id], on_delete: "CASCADE")
```

### def rename\_column`(old_name : Symbol, new_name : Symbol)`

Renames a column in the table.

* **@param** old\_name \[Symbol] the current name of the column
* **@param** new\_name \[Symbol] the new name for the column

**Example** Renaming a column

```crystal
  rename_column(:email, :user_email)
```

### def rename\_table`(new_name : Symbol)`

Renames the table.

* **@param** new\_name \[Symbol] the new name for the table

**Example** Renaming the table

```crystal
rename_table(:new_table_name)
```

### def to\_sql`(visitor : Expression::Visitor)`

Converts the alter table actions to SQL.

* **@param** visitor \[Expression::Visitor] the visitor to generate SQL
* **@return** \[String] the generated SQL

**Example** Generating SQL for alter table actions

```crystal
sql = to_sql(visitor)
```
