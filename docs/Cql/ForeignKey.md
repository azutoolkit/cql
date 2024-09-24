---
title: "CQL::ForeignKey"
---

# class CQL::ForeignKey

`Reference` < `Object`

The `CQL::ForeignKey` class defines a foreign key constraint between two tables. It allows you to specify the columns, referenced table, and the actions to be taken on `DELETE` or `UPDATE`.

## Example: Creating a Foreign Key

```crystal
schema.build do
  table :users do
    column :id, Int32, primary: true
    column :name, String
  end
end

table :posts do
  column :id, Int32, primary: true
  column :user_id, Int32, foreign_key: true
end
```

## Constructors

### def new(columns : Array(Symbol), references : Symbol, on_delete : Symbol = :restrict, on_update : Symbol = :restrict)

Creates a new foreign key constraint.

- **@param** columns \[Array(Symbol)] The columns in the current table.
- **@param** references \[Symbol] The referenced table.
- **@param** on_delete \[Symbol] Action to take on delete (`:restrict`, `:cascade`, `:set_null`).
- **@param** on_update \[Symbol] Action to take on update (`:restrict`, `:cascade`, `:set_null`).
- **@return** \[ForeignKey] The created foreign key object.

**Example**:

```crystal
foreign_key = CQL::ForeignKey.new([:user_id], :users, on_delete: :cascade)
```

## Methods

### def on_delete(action : Symbol)

Sets the action to take when a referenced record is deleted.

- **@param** action \[Symbol] The action (`:restrict`, `:cascade`, `:set_null`).
- **@return** \[ForeignKey] The updated foreign key object.

**Example**:

```crystal
foreign_key.on_delete(:cascade)
```

### def on_update(action : Symbol)

Sets the action to take when a referenced record is updated.

- **@param** action \[Symbol] The action (`:restrict`, `:cascade`, `:set_null`).
- **@return** \[ForeignKey] The updated foreign key object.

**Example**:

```crystal
foreign_key.on_update(:restrict)
```
