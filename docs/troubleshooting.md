---
icon: life-ring
---

# Troubleshooting CQL

Here are some common issues you might encounter while using CQL and how to resolve them.

## Issue: `NoMethodError` when querying

### Solution:

Ensure that your table and columns are correctly defined in the schema. For example:

```crystal
table :users do
  primary :id, Int64
  column :name, String
end
```

If you're querying a column that doesn't exist, CQL will raise a `NoMethodError`.

## Issue: Transaction not rolling back

### Solution:

Ensure that any errors raised inside the transaction block are properly handled. If an error occurs, the transaction will be rolled back automatically.
