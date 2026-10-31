---
description: "Run the same models on caller-owned databases and transactions without changing global configuration."
---

# Bind Models to a Database or Transaction

Declare a mapping without opening a pool, then supply the execution resource explicitly:

```crystal
require "cql"
require "sqlite3"

Accounts = CQL::Schema.define(:accounts, adapter: CQL::Adapter::SQLite) do
  table :accounts do
    primary :id, UUID
    text :name
  end
end

class Account
  include CQL::Model(UUID)
  db_context schema: Accounts, table: :accounts
  property name : String = ""
end

DB.open("sqlite3://./accounts.db") do |db|
  binding = CQL::Binding.new(db)
  Accounts.bind(binding).build
  accounts = Account.on(binding)
  account = accounts.create!(name: "Ada")
  account.name = "Ada Lovelace"
  account.save!
  account.reload!
  accounts.where(name: "Ada Lovelace").first!
end
```

`Schema#bind` and `Model.on` accept `DB::Database`, `DB::Connection`, `DB::Transaction`, or a reusable `CQL::Binding`. Reuse one binding for models participating in the same operation: it caches independent declaration copies and shares CQL transaction frames across their schemas. CQL keeps no global tenant-binding cache. Closing a bound schema never closes the caller's pool or releases a supplied connection.

A declaration-only mapping generates SQL but raises on execution until bound. Its `uri?` is nil; `uri` raises. Existing URI-backed mappings keep their original ownership behavior and can also be bound.

## Queries, records, and associations

Bound queries preserve scopes and default predicates, including soft-delete filters. Hydrated and built records carry a serialization-ignored `binding`; saves, reloads, deletes, preloads, lazy associations, and relationship writes use it. Queries and records from different bindings cannot be combined. Struct models return updated values, and preloads replace the corresponding array entries.

`Account.on(binding)` provides queries, `build`, `create!`, `insert_all`, `upsert_all`, update/delete operations, soft-delete restoration, and `transaction`. Low-level builders are also available as `Account.insert(binding)`, `.update(binding)`, and `.delete(binding)`. Explicit insert builders retain supplied natural keys and run no callbacks.

Callbacks run on the bound record. An explicitly qualified call to another model must pass the context, for example `Audit.on(binding).create!(action: "changed")` inside a record method. Application class methods are not automatically delegated by the bound receiver. Tenant predicates and PostgreSQL schema selection remain application-owned.

## Borrow an outer transaction

```crystal
DB.open("sqlite3://./accounts.db") do |db|
  db.transaction do |outer|
    binding = CQL::Binding.new(outer)
    accounts = Account.on(binding)
    accounts.create!(name: "Visible before commit")
    accounts.transaction do |inner|
      accounts.create!(name: "Rolled back to the savepoint")
      inner.rollback
    end
    outer.rollback
  end
end
```

Passing the transaction object allows nested savepoints. CQL never commits or rolls back the caller's outer transaction. A binding rejects execution after that transaction closes. A bare connection does not expose its external transaction owner; pass the transaction object when an operation needs nested transactions. Caller-managed rollback does not promise restoration of in-memory records.

`Account.query.using(connection)` and `.using(transaction)` use the same binding machinery. Generic `CQL::Executor` objects remain available for reads through `using`; records hydrated through them reject writes and transaction operations that the executor cannot provide. Raw CQL statements retain their existing `using` behavior.

`CQL::SchemaDump.open(bound_schema)` inspects the supplied source, including uncommitted tables, without reopening the mapping URI.

## Isolate migration streams

```crystal
config = CQL::MigratorConfig.new(
  migration_namespace: "AccountsApp::Migrations",
  migration_table_name: :accounts_migrations,
  auto_sync: false)
DB.open("sqlite3://./accounts.db") do |db|
  schema = Accounts.bind(db)
  ready = CQL::Migrator.ready?(schema, config)
  CQL::Migrator.new(schema, config).up unless ready
end
```

The namespace matches full module boundaries: `AccountsApp::Migrations::CreateAccounts` belongs, `AccountsApp::MigrationsExtra::CreateAccounts` does not. A trailing `::` is optional; a blank namespace is rejected. Selection applies to version validation, history, pending migrations, targets, rollback, redo, and reviewed execution. History remains visible when a source file is missing.

Independent streams in one physical database should use separate `migration_table_name` values. A selected version recorded for another namespace in a shared ledger is rejected under the migration lock before migration DDL runs.

`Migrator.ready?` only probes ledger existence and reads history. It creates no table, mutates no declarations, and takes no migration lock. An absent ledger returns false, including inside a PostgreSQL transaction without aborting it.
