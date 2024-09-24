---
title: "CQL::AlterTable"
---

# class CQL::AlterTable

`Reference` < `Object`

The `CQL::AlterTable` class is responsible for handling alterations to the database schema. It allows you to add, drop, rename, and change columns in a table.

## Example: Altering a Table

```crystal
alter_table = AlterTable.new
alter_table.add_column(:email, "string")
alter_table.drop_column(:age)
alter_table.rename_column(:email, :user_email)
alter_table.change_column(:age, "string")
```

## Constructors

### def new

Creates a new `AlterTable` object.

- **@return** \[AlterTable] The new alter table object.

## Methods

### def add_column(column : Symbol, type : String)

Adds a new column to the table.

- **@param** column \[Symbol] The name of the column to add.
- **@param** type \[String] The data type of the new column.
- **@return** \[AlterTable] The updated alter table object.

**Example**:

```crystal
alter_table.add_column(:email, "string")
```

### def drop_column(column : Symbol)

Drops a column from the table.

- **@param** column \[Symbol] The name of the column to drop.
- **@return** \[AlterTable] The updated alter table object.

**Example**:

```crystal
alter_table.drop_column(:age)
```

### def rename_column(old_name : Symbol, new_name : Symbol)

Renames a column in the table.

- **@param** old_name \[Symbol] The current name of the column.
- **@param** new_name \[Symbol] The new name for the column.
- **@return** \[AlterTable] The updated alter table object.

**Example**:

```crystal
alter_table.rename_column(:email, :user_email)
```

### def change_column(column : Symbol, new_type : String)

Changes the data type of a column.

- **@param** column \[Symbol] The name of the column to change.
- **@param** new_type \[String] The new data type for the column.
- **@return** \[AlterTable] The updated alter table object.

**Example**:

```crystal
alter_table.change_column(:age, "string")
```
