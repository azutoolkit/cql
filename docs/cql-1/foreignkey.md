---
title: Cql::ForeignKey
---

# class Cql::ForeignKey

`Reference` < `Object`

A foreign key constraint This class represents a foreign key constraint It provides methods for setting the columns, table, and references It also provides methods for setting the on delete and on update actions

**Example** Creating a new foreign key

```crystal
schema.build do
  table :users do
    column :id, Int32, primary: true
    column :name, String
  end
end

table :posts do
  column :id, Int32, primary: true
  column :user_id, Int32
  foreign_key [:user_id], :users, [:id]
end
```

details Table of Contents \[\[toc]]

## Constructors

### def new`(name : Symbol, columns : Array(Symbol), table : Symbol, references : Array(Symbol), on_delete : String = "NO ACTION", on_update : String = "NO ACTION")`
