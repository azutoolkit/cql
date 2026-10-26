---
description: "Generate a schema file from a live database, keep it in sync with migrations, and check that models still match it."
---

# Dump and Validate Your Schema

| Tool | Compares or reads | Gives |
| :--- | :--- | :--- |
| `CQL::SchemaDump` | a live database | a `CQL::Schema.define` file |
| `Migrator#verify_schema_consistency` | the database and the schema file | `Bool` |
| `CQL::ActiveRecord::SchemaValidator` | a `CQL::Schema` and the model getters | `SchemaMappingError` on a mismatch |

## Generate a Schema File From a Database

```crystal
dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, "sqlite3://db/myapp.db")
dumper.dump_to_file("src/schemas/myapp_schema.cr", :MyApp, :myapp) # creates directories, overwrites the file
dumper.close

dumper = AppDB.schema_dumper                                 # same as CQL::SchemaDump.from_schema(AppDB)
text = dumper.generate_schema_content(:AppSchema, :app_schema) # the file's text, nothing written
dumper.dump_to_file                                          # ./src/schemas/schema.cr, :AppSchema, :app_schema
dumper.close
```

{% code title="src/schemas/myapp_schema.cr" %}
```crystal
MyApp = CQL::Schema.define(
  :myapp,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://db/myapp.db") do
  table :users do
    primary :id, Int32
    text :name
    text :email
    text :role, default: "'member'"
    text :bio, null: true
    timestamps
  end

  table :posts do
    primary :id, Int32
    text :title
    integer :views, default: "0"
    bigint :user_id
    timestamps
    foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: :cascade, on_update: :no_action
  end

end
```
{% endcode %}

- SQLite, MySQL, PostgreSQL and CockroachDB (through the PostgreSQL path) are read. Unknown types become `text`.
- A one-column primary key gets `primary`; a composite key gets none. SQLite reports every `INTEGER PRIMARY KEY` as
  `Int32`, including keys declared `Int64`; edit those lines for `Model(Int64)` models.
- `created_at` plus `updated_at` become `timestamps`. Defaults are copied as the database reports them, as strings.
- Foreign keys are written one column each. PostgreSQL and MySQL omit `no_action` rules; SQLite writes them.
- Indexes are not dumped. The migrations table is, like any other table.

{% hint style="danger" %}
The URI, password included, is written into the file. Dump with a URI without credentials, or edit the `uri:` line before committing.
{% endhint %}

## Keep the File in Sync With Migrations

```crystal
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  schema_symbol: :app_schema,
  auto_sync: true
)
migrator = AppDB.migrator(config)  # writes the file now if it is missing
migrator.up                        # and again after every up and down
migrator.update_schema_file        # on demand; bootstrap_schema does the same
```

## Check the File for Drift

```crystal
check = AppDB.migrator(config)  # leaves an existing file alone, even with auto_sync: true
abort "src/schemas/app_schema.cr is out of date" unless check.verify_schema_consistency

CQL.verify_schema(AppDB)                 # the same check, configured from CQL.configure
CQL.verify_schema(AppDB, auto_fix: true) # with auto_sync on, rewrites a stale file and returns true
```

`verify_schema_consistency` regenerates the text and compares it exactly, so hand edits count as drift. It returns
`false` when the file is missing, differs, or the database cannot be read. Check before `up` or `down`: with
`auto_sync: true` they rewrite the file.

## Dump Raw DDL

```crystal
File.write("db/structure.sql", AppDB.dialect.structure_dump(URI.parse(AppDB.uri)))
```

| Adapter | `structure_dump(uri)` runs |
| :--- | :--- |
| PostgreSQL | `pg_dump --schema-only --no-comments --no-password --host=... --port=... --username=... --dbname=...`, with the password in `PGPASSWORD` and the URL's `sslmode` in `PGSSLMODE` |
| MySQL | `mysqldump --defaults-extra-file=<temporary 0600 file holding the password> --no-data --skip-comments --compact --host=... --port=... --user=... --protocol=tcp <database>` (`--protocol=tcp` only with a port) |
| SQLite | nothing: returns `""` |
| CockroachDB | nothing: raises `CQL::DialectError` (run `SHOW CREATE ALL TABLES`) |

The host, port, user, password and database come from the URI, percent-decoded, and the password never appears on
the command line. Of the URL's query parameters only PostgreSQL's `sslmode` is used; the others are ignored. The tool
must be on `PATH`; when it is missing or fails, `structure_dump` raises `CQL::Error` with its stderr.

## Validate Models Against the Schema

```bash
CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal spec   # checks every model before the first example
```

```text
CQL schema mapping error in User: schema column `users.name` type String does not match model getter `name` type Int32. Update the schema column or the model property type.
```

```crystal
# At boot, before the server starts: the same check, one model at a time
CQL::ActiveRecord::SchemaValidator.validate_model!(
  "User", AppDB, :users,
  {"id" => "Int64 | ::Nil", "name" => "String"}, # getter name => type name
  primary_key: :id
)
```

With the variable set, each model runs the check once, after the program's top-level code. That suits specs, which
start after it, but an app that blocks in `server.listen` never reaches it, so call `validate_model!` there.

- A model whose table is not in the schema fails, and so does a table whose primary key is not the model's
  `primary_key:`.
- Only columns with a zero-argument getter of the same name are compared. `Nil` is ignored, so `Int64?` matches an
  `Int64` column, and a `UUID` getter matches a `String` column. See [Fix Schema Mapping Errors](../troubleshooting/schema-mapping-errors.md).

## See Also

- [Run Migrations](run-migrations.md)
- [Create a Migration](create-migration.md)
- [Fix Schema Mapping Errors](../troubleshooting/schema-mapping-errors.md)
- [Configure CQL](../configuration/configure-cql.md)
