---
title: "Cql::PrimaryKey(T)"
---

::: v-pre
# class Cql::PrimaryKey(T)
`Cql::Column` < `Cql::BaseColumn` < `Reference` < `Object`

Primary key column definition

**Example:**

```crystal
schema.table :users do
  primary :id, Int32
  column :name, String
end
```
::: details Table of Contents
[[toc]]
:::



## Constructors


### def new`(name : Symbol = :id, type : PrimaryKeyType = Int64.class, as_name : String | Nil = nil, auto_increment : Bool = true, unique : Bool = true, default : DB::Any = nil)`





## Instance Methods


### def as_name






### def auto_increment?






### def unique?

:nodoc:



:::