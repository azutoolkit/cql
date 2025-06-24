# Schema Dump

The `CQL::SchemaDump` class provides functionality to reverse-engineer existing database schemas and generate CQL schema definition files. This is useful when you have an existing database and want to create a CQL schema that matches its structure.

**🆕 Integration with Migrations**: Schema dumping is now integrated with the migration system to provide automatic schema file synchronization. See [Integrated Migration Workflow](active-record-with-cql/integrated-migration-workflow.md) for the complete workflow.

## Overview

Schema dumping allows you to:

- Inspect existing database tables, columns, indexes, and foreign keys
- Automatically map SQL types to the correct CQL column methods
- Generate idiomatic CQL schema files using proper method calls
- Smart detection of timestamps for clean `timestamps` macro usage
- Support SQLite, PostgreSQL, and MySQL databases

## Basic Usage

### Creating a Schema Dumper

```crystal
require "cql"

# For SQLite
dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, "sqlite3://path/to/database.db")

# For PostgreSQL
dumper = CQL::SchemaDump.new(CQL::Adapter::Postgres, "postgresql://user:pass@localhost/database")

# For MySQL
dumper = CQL::SchemaDump.new(CQL::Adapter::MySql, "mysql://user:pass@localhost/database")
```

### Generating Schema Files

```crystal
# Dump schema to a file
dumper.dump_to_file("src/schemas/my_schema.cr", :MySchema, :my_schema)

# Generate schema content as a string
content = dumper.generate_schema_content(:MySchema, :my_schema)
puts content

# Always close the connection when done
dumper.close
```

## Generated Schema Format

The generated schema files follow the standard CQL schema format:

```crystal
MySchema = CQL::Schema.define(
  :my_schema,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://path/to/database.db") do

  table :users do
    primary :id, Int32
    text :name
    text :email, null: true
    integer :age
    timestamps
  end

  table :posts do
    primary :id, Int32
    text :title
    text :body
    integer :user_id, null: true
    foreign_key [:user_id], references: :users, references_columns: [:id]
  end
end
```

## Type Mapping

The schema dumper automatically maps SQL types to the appropriate CQL column methods:

### SQLite Type Mapping

- `INTEGER` → `integer` (Int32)
- `BIGINT` → `bigint` (Int64)
- `TEXT` → `text` (String)
- `VARCHAR` → `text` (String)
- `BOOLEAN` → `boolean` (Bool)
- `TIMESTAMP` → `timestamp` (Time)
- `BLOB` → `blob` (Slice(UInt8))
- `JSON` → `json` (JSON::Any)

### PostgreSQL Type Mapping

- `integer` → `integer` (Int32)
- `bigint` → `bigint` (Int64)
- `text` → `text` (String)
- `varchar` → `text` (String)
- `boolean` → `boolean` (Bool)
- `timestamp` → `timestamp` (Time)
- `bytea` → `blob` (Slice(UInt8))
- `jsonb` → `json` (JSON::Any)

### MySQL Type Mapping

- `INT` → `integer` (Int32)
- `BIGINT` → `bigint` (Int64)
- `VARCHAR` → `text` (String)
- `TEXT` → `text` (String)
- `TINYINT(1)` → `boolean` (Bool)
- `DATETIME` → `timestamp` (Time)
- `BLOB` → `blob` (Slice(UInt8))
- `JSON` → `json` (JSON::Any)

## Features

### Table Structure

- Extracts table names and generates `table` blocks
- Identifies primary keys and generates `primary` declarations
- Uses the correct CQL column methods (`integer`, `text`, `boolean`, etc.)
- Maps all column types with proper nullability
- Handles default values when present

### Column Method Generation

- Automatically uses the appropriate CQL column methods instead of generic `column` calls
- Maps `INTEGER` → `integer`, `TEXT` → `text`, `BOOLEAN` → `boolean`, etc.
- Generates clean, idiomatic CQL schema definitions
- Follows the same patterns used throughout the CQL codebase

#### Before vs After Example

**Before (Generic approach):**

```crystal
table :users do
  primary :id, Int32
  column :name, String
  column :age, Int32
  column :active, Bool
  column :created_at, Time
  column :updated_at, Time
end
```

**After (CQL-specific methods):**

```crystal
table :users do
  primary :id, Int32
  text :name
  integer :age
  boolean :active
  timestamps
end
```

### Foreign Keys

- Detects foreign key relationships
- Generates `foreign_key` declarations with proper references
- Includes ON DELETE and ON UPDATE actions when specified
- Supports composite foreign keys

### Smart Timestamps

- Automatically detects `created_at` and `updated_at` columns
- Generates the `timestamps` macro when both are present
- Excludes individual timestamp columns when using the macro
- Produces cleaner, more maintainable schema definitions

## Complete Example

```crystal
require "cql"

# Connect to existing database
dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, "sqlite3://myapp.db")

begin
  # Generate and save schema
  dumper.dump_to_file("src/schemas/myapp_schema.cr", :MyAppDB, :myapp_db)
  puts "Schema successfully dumped to src/schemas/myapp_schema.cr"

  # You can also get the content as a string
  schema_content = dumper.generate_schema_content(:MyAppDB, :myapp_db)
  puts "Generated schema:"
  puts schema_content

ensure
  # Always close the connection
  dumper.close
end
```

## Use Cases

### Database Migration

Convert an existing database to use CQL:

1. Dump the existing schema using `SchemaDump`
2. Review and adjust the generated schema as needed
3. Use the schema in your CQL application

### 🆕 Migration Integration

The schema dump functionality is now integrated with the migration system:

```crystal
# Automatic schema synchronization with migrations
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  auto_sync: true
)

migrator = AppDB.migrator(config)

# Bootstrap from existing database
migrator.bootstrap_schema  # Uses SchemaDump internally

# Run migrations - schema file automatically updated
migrator.up  # Uses SchemaDump to keep schema file current

# Manual schema updates
migrator.update_schema_file  # Uses SchemaDump to regenerate schema
```

### Schema Documentation

Generate up-to-date schema documentation by dumping the current database structure.

### Testing

Create test schemas that match your production database structure.

## Limitations

- Views are not included in the dump (only base tables)
- Indexes are not yet included (coming in future versions)
- Some database-specific types may fall back to generic `text` columns
- Complex constraints beyond foreign keys are not included
- UInt32 and UInt64 types map to `integer` and `bigint` respectively (no specific unsigned methods in CQL)

## Error Handling

The schema dumper includes proper error handling:

```crystal
begin
  dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, "sqlite3://invalid.db")
rescue CQL::SchemaDump::Error => ex
  puts "Failed to connect: #{ex.message}"
end
```

## Tips

1. **Review Generated Schemas**: Always review the generated schema files before using them in production
2. **Idiomatic CQL**: The generated schemas now use proper CQL column methods (`integer`, `text`, etc.) that match the CQL coding style
3. **Timestamps Macro**: When both `created_at` and `updated_at` columns are detected, the dumper automatically uses the `timestamps` macro
4. **Custom Types**: You may need to manually adjust some type mappings for domain-specific needs
5. **Backup First**: Always backup your database before making changes based on dumped schemas
6. **Connection Management**: Always call `close()` on the dumper when finished to free database connections

---

## Recent Improvements

### v2.0 - Enhanced Column Method Generation

- ✅ **Proper CQL Methods**: Now generates `integer`, `text`, `boolean`, etc. instead of generic `column` calls
- ✅ **Smart Timestamps**: Automatically detects and uses `timestamps` macro when both `created_at` and `updated_at` are present
- ✅ **Idiomatic Output**: Generated schemas match the exact style used throughout the CQL codebase
- ✅ **Cleaner Code**: Produces more maintainable and readable schema definitions

**Before:**

```crystal
column :name, String
column :age, Int32
column :created_at, Time
column :updated_at, Time
```

**After:**

```crystal
text :name
integer :age
timestamps
```
