---
title: "CQL::Migrator"
---

# class CQL::Migrator

`Reference` < `Object`

The `CQL::Migrator` class is responsible for managing database migrations. It provides methods to apply, roll back, and redo migrations, as well as list applied and pending migrations.

## Example: Creating a Migrator

```crystal
migrator = CQL::Migrator.new(schema)
```

## Methods

### def up

Applies pending migrations.

- **@return** \[Nil]

**Example**:

```crystal
migrator.up
```

### def down

Rolls back the last migration.

- **@return** \[Nil]

**Example**:

```crystal
migrator.down
```

### def redo

Reapplies the last migration by rolling it back and applying it again.

- **@return** \[Nil]

**Example**:

```crystal
migrator.redo
```

### def applied

Lists the migrations that have already been applied.

- **@return** \[Array(String)] The list of applied migrations.

**Example**:

```crystal
migrator.applied
```

### def pending

Lists the migrations that have not yet been applied.

- **@return** \[Array(String)] The list of pending migrations.

**Example**:

```crystal
migrator.pending
```
