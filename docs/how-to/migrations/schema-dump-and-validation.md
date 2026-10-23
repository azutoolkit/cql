# Dump and Validate Your Schema

This guide shows you how to turn an existing database into a CQL schema file, keep that file in sync with migrations, and check that your models still match it.

There are three separate tools:

| Tool | Reads | Produces |
| --- | --- | --- |
| `CQL::SchemaDump` | a live database | a Crystal schema file |
| `structure_dump` (dialect) | a live database | raw DDL from `pg_dump` / `mysqldump` |
| `CQL::ActiveRecord::SchemaValidator` | your `CQL::Schema` and model getters | an error if the types disagree |

## Generate a Schema File From a Database

`SchemaDump` inspects tables, columns and foreign keys and writes a `CQL::Schema.define` block.

```crystal
dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, "sqlite3://db/myapp.db")
dumper.dump_to_file("src/schemas/myapp_schema.cr", :MyApp, :myapp)
dumper.close
```

`dump_to_file` takes three optional arguments:

| Argument | Default |
| --- | --- |
| `file_path` | `"./src/schemas/schema.cr"` (`SchemaDump::DEFAULT_SCHEMA_DUMP_FILE_PATH`) |
| `schema_name` | `:AppSchema`, the constant in the generated file |
| `schema_symbol` | `:app_schema`, the name passed to `CQL::Schema.define` |

Missing directories are created. An existing file is overwritten.

### Build It From a Schema You Already Have

```crystal
dumper = MyDB.schema_dumper            # same as CQL::SchemaDump.from_schema(MyDB)
puts dumper.generate_schema_content(:AppSchema, :app_schema)
dumper.close
```

`generate_schema_content` returns the file text without writing it, which is handy for a diff or a spec.

### What the Output Looks Like

```crystal
AppSchema = CQL::Schema.define(
  :app_schema,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://db/myapp.db") do
  table :posts do
    primary :id, Int32
    text :title
    text :body, null: true
    integer :user_id
    timestamps
    foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: :cascade
  end

end
```

### What Is Mapped

- SQLite, MySQL, PostgreSQL and CockroachDB are inspected. CockroachDB uses the PostgreSQL path.
- A table with exactly one primary key column gets `primary :name, Type`. A table with a composite key gets no `primary` line.
- A table with both `created_at` and `updated_at` gets the `timestamps` macro instead of two columns.
- Nullable columns get `null: true`; column defaults are written as `default: "..."` strings.
- Foreign keys are written one column at a time. On PostgreSQL and MySQL, `on_delete` / `on_update` are omitted when the rule is `no_action`; SQLite always writes them.
- Types it does not recognise fall back to `String` (`text`).

Indexes are not dumped. Treat the generated file as a starting point and add the pieces it cannot see.

**Warning:** the database URI, including any password, is written into the generated file. Pass a URI without credentials, or edit the `uri:` line before you commit the file.

## Keep the File in Sync With Migrations

The migrator rewrites the schema file after `up` and `down` when `auto_sync` is on (the default):

```crystal
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  schema_symbol: :app_schema,
  auto_sync: true
)
migrator = MyDB.migrator(config)

migrator.up                       # runs migrations, then rewrites the file
migrator.update_schema_file       # rewrite it on demand
migrator.bootstrap_schema         # same thing, for an existing database
```

To check whether the file has drifted, without changing it:

```crystal
unless migrator.verify_schema_consistency
  abort "src/schemas/app_schema.cr is out of date. Run migrations or update_schema_file."
end
```

`verify_schema_consistency` regenerates the schema text and compares it to the file. It returns `false` when the file is missing, differs, or the database cannot be read. The comparison is exact text, so keep hand edits out of generated files (see [Run Migrations](run-migrations.md)).

`CQL.verify_schema(schema, auto_fix: true)` does the same check and rewrites the file when `auto_sync` is enabled in your configuration.

## Raw Structure Dumps

Each dialect exposes `structure_dump(uri)`, which returns the database DDL as a string using the vendor's own tool:

```crystal
dialect = CQL::Adapter::Postgres.dialect
ddl = dialect.structure_dump(URI.parse("postgresql://app@localhost/app_db"))
File.write("db/structure.sql", ddl)
```

| Adapter | Behavior |
| --- | --- |
| PostgreSQL | runs `pg_dump --schema-only --no-data --no-comments`, using the user and database name from the URI |
| MySQL | runs `mysqldump --no-data --skip-comments --compact`, using user, password and database name from the URI |
| SQLite | returns an empty string |
| CockroachDB | raises `CQL::DialectError`; run `SHOW CREATE ALL TABLES` instead |

`pg_dump` and `mysqldump` must be installed and on `PATH`. The PostgreSQL call passes only the user, so supply the password through `PGPASSWORD` or `~/.pgpass`.

## Validate Models Against the Schema

`SchemaValidator` compares each model getter with the schema column of the same name and raises `CQL::ActiveRecord::SchemaMappingError` on a type mismatch.

It runs once per model, when the program starts, if you set an environment variable:

```bash
CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal run src/app.cr
```

The error names the model, column and both types:

```text
CQL schema mapping error in User: schema column `users.name` type String does not match model getter `name` type Int32. Update the schema column or the model property type.
```

See [Fix Schema Mapping Errors](../troubleshooting/schema-mapping-errors.md) for fixes.

### Rules

- A model whose table is not in the schema raises `table ... is not defined in schema ...`.
- Only columns that have a matching zero-argument getter are compared. Columns the model does not expose are fine.
- `Nil` is ignored on both sides, so `Int64?` matches an `Int64` column.
- A `UUID` getter matches a `String` column, because UUIDs are stored as text (see [UUID and ULID Primary Keys](../models/uuid-ulid-primary-keys.md)).

### Call It Yourself

You can run the same check in a spec or a boot script:

```crystal
CQL::ActiveRecord::SchemaValidator.validate_model!(
  "User",
  MyDB,
  :users,
  {"id" => "Int64 | ::Nil", "name" => "String"}
)
```

The last argument maps getter names to their type names.

## Recommended Workflow

1. Write and run migrations with `auto_sync: true` in development, so the schema file follows the database.
2. Commit the schema file.
3. In CI, run `verify_schema_consistency` against a freshly migrated database.
4. Run the specs, or a boot check, with `CQL_VALIDATE_SCHEMA_MAPPINGS=1` to catch model drift.

## Related

- [Run Migrations](run-migrations.md)
- [Create a Migration](create-migration.md)
- [Fix Schema Mapping Errors](../troubleshooting/schema-mapping-errors.md)
