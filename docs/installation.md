---
description: "Add CQL and your database's driver to a Crystal project, then check that it connects."
icon: "download"
---

# Installation

CQL needs Crystal 1.12.2 or later (`shard.yml`); CI builds with Crystal 1.22.0.

## 1. Add CQL and Your Driver

Each tab shows one database's `shard.yml` dependencies, `require` lines, and the adapter and URL its schema takes.

{% tabs %}
{% tab title="SQLite" %}
{% code title="shard.yml" %}
```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: ~> 0.0.808
  sqlite3:
    github: crystal-lang/crystal-sqlite3
```
{% endcode %}

```crystal
require "cql"
require "sqlite3"

CQL::Adapter::SQLite # "sqlite3://./db/app.db"
```
{% endtab %}

{% tab title="PostgreSQL" %}
{% code title="shard.yml" %}
```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: ~> 0.0.808
  # No driver shard: CQL ships its own PostgreSQL driver
```
{% endcode %}

```crystal
require "cql" # postgres:// and postgresql:// URLs now open through CQL's driver

AppDB = CQL::Schema.define(:app, adapter: CQL::Adapter::Postgres,
  uri: "postgres://app:secret@localhost:5432/app?sslmode=require&max_pool_size=20") do
  table :users do
    primary :id, Int64, auto_increment: true
    text :name
  end
end
# sslmode: disable, prefer (default), require or verify-full.
# Pool settings are crystal-db URL options: initial_pool_size, max_pool_size, checkout_timeout, retry_attempts.
```

{% hint style="info" %}
If your app requires the `pg` shard anywhere, that shard serves `postgres://` URLs instead. Compile with `-Dcql_no_postgres_driver` to keep CQL's driver out of crystal-db's registry.
{% endhint %}
{% endtab %}

{% tab title="MySQL" %}
{% code title="shard.yml" %}
```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: ~> 0.0.808
  mysql:
    github: crystal-lang/crystal-mysql
```
{% endcode %}

```crystal
require "cql"
require "mysql"

CQL::Adapter::MySql # "mysql://app:secret@localhost:3306/app"
```
{% endtab %}

{% tab title="CockroachDB" %}
{% code title="shard.yml" %}
```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: ~> 0.0.808
  # No driver shard: CQL's PostgreSQL driver also serves CockroachDB
```
{% endcode %}

```crystal
require "cql"

CQL::Adapter::CockroachDB # "cockroachdb://root@localhost:26257/app"
```

A schema with this adapter and URL uses the native driver as is; `DB.open("cockroachdb://...")` needs `CQL::Postgres::Driver.register_cockroachdb` or `-Dcql_postgres_driver_cockroachdb`.
{% endtab %}
{% endtabs %}

```bash
shards install   # also installs db (crystal-db), ulid and redis, which CQL depends on
```

## 2. Check the Connection

{% code title="src/check_cql.cr" %}
```crystal
require "cql"
require "sqlite3"

AppDB = CQL::Schema.define(:app, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :users do
    primary :id, Int64, auto_increment: true
    text :name
  end
end

AppDB.users.create! # CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)
id = AppDB.insert.into(:users).values(name: "Ada").last_insert_id
puts AppDB.query.from(:users).select(:name).where(id: id).get(as: String)
```
{% endcode %}

```bash
crystal run src/check_cql.cr
# Ada
# 2026-10-26T11:31:33.209740Z  DEBUG - CQL::Development: Creating table users   (CQL's development log)
```

For another database, change `adapter:` and `uri:` and the `require` lines to the ones in its tab. The [first tutorial](tutorials/getting-started/your-first-cql-app.md) continues from here with models and migrations.

## Troubleshooting

**`shards install` rejects a shard's Crystal version**: run `shards install --ignore-crystal-version`, as CI does.

**`DB::ConnectionRefused` or `cannot connect to localhost:5432`**: the server is not running or the host, port or credentials in the URL are wrong; see [Fix Connection Errors](how-to/troubleshooting/connection-errors.md).

## See Also

- [Your First CQL App](tutorials/getting-started/your-first-cql-app.md)
- [Configure Database Connection](how-to/configuration/database-connection.md)
- [Configure CQL](how-to/configuration/configure-cql.md)
- [Configure Multiple Environments](how-to/configuration/environments.md)
- [Native PostgreSQL Driver](how-to/postgres-native/README.md)
- [Use CockroachDB](how-to/configuration/cockroachdb.md)
