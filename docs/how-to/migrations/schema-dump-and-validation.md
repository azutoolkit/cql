# Dump and Validate Your Schema

Generate a schema file from a live database, keep it in sync with migrations, and check that models still match it.

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

```crystal
# src/schemas/myapp_schema.cr
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
migrator = AppDB.migrator(config)  # writes the file now
migrator.up                        # and again after every up and down
migrator.update_schema_file        # on demand; bootstrap_schema does the same
```

## Check the File for Drift

```crystal
# ❌ auto_sync: true rewrites the file when the migrator is built, so a stale file passes
AppDB.migrator(config).verify_schema_consistency  # => true

# ✅ Check with a migrator that leaves the file alone
check = AppDB.migrator(CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  auto_sync: false
))
abort "src/schemas/app_schema.cr is out of date" unless check.verify_schema_consistency
```

`verify_schema_consistency` regenerates the text and compares it exactly, so hand edits count as drift. It returns
`false` when the file is missing, differs, or the database cannot be read. `CQL.verify_schema(AppDB)` builds its
migrator from `CQL.configure`, so it only detects drift with `auto_sync = false`, and then `auto_fix: true` has
nothing to fix with.

## Dump Raw DDL

```bash
pg_dump --schema-only --no-comments --username=app app_db > db/structure.sql
mysqldump --no-data --skip-comments --compact --user=app -p app_db > db/structure.sql
```

Run the tools yourself. The dialects' `structure_dump(uri)` returns `""` on SQLite, raises `CQL::DialectError` on
CockroachDB, and on PostgreSQL and MySQL currently returns the pipe's description (`#<IO::FileDescriptor:...>`),
not the DDL.

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
