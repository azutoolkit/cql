---
title: Cql::Adapter
---

# enum Cql::Adapter

`Enum` < `Comparable` < `Value` < `Object`

Represents a database adapter module. details Table of Contents \[\[toc]]

## Constants

### Sqlite

```crystal
0
```

### MySql

```crystal
1
```

### Postgres

```crystal
2
```

## Instance Methods

### def my\_sql?

### def postgres?

### def sql\_type`(type) : String`

Returns the SQL type for the given type. @param type \[Type] the type @return \[String] the SQL type **Example** Getting the SQL type

```crystal
Cql::Adapter::Sqlite.sql_type(Int32) # => "INTEGER"
```

### def sqlite?
