# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Comprehensive CHANGELOG.md for tracking changes
- Performance monitoring system with N+1 query detection
- Multi-layer caching architecture (memory, Redis, fragment, request-scoped)
- Query profiling and slow query detection
- Advanced configuration system via `CQL.configure`
- Support for UUID and ULID primary keys
- Optimistic locking support
- Soft delete functionality
- Query scopes for reusable query patterns
- Lifecycle callbacks (before/after validation, save, create, update, destroy)
- Comprehensive validation system
- Schema dump functionality for reverse-engineering databases
- Migration system with rollback support
- Support for Active Record, Repository, and Data Mapper patterns
- Full support for PostgreSQL, MySQL, and SQLite
- Compile-time FK/PK validation for `belongs_to` and `has_many`, including associations whose target model is defined later in the program
- Opt-in schema mapping validation via `CQL_VALIDATE_SCHEMA_MAPPINGS=1`
- **New API methods for consistency (v0.0.436+)**:
  - `Query#get!` - Raises exception if scalar value not found (matches `first!` pattern)
  - `Query#where_null(field)` - Explicit IS NULL condition for better clarity
  - `Query#where_not_null(field)` - Explicit IS NOT NULL condition for better clarity

### Changed

- **`QueryBuilder#where { }`, `join { }`, `left { }`, `right { }` return a new builder** like every other builder method; they no longer also mutate the receiver. Use the returned value.
- Aggregates accept `as:` for a select-list alias: `count(:id, as: "n")`.
- Opt-in identifier quoting: `CQL::Schema.define(..., quote_identifiers: true)` quotes table, column and alias names (double quotes, backticks on MySQL). Default is off, so generated SQL is unchanged. Quoting covers queries and DML only; DDL (`build`, migrations, `alter`) is not quoted yet.

- Improved error handling with detailed exception hierarchy
- Enhanced N+1 query detection with better pattern recognition
- Optimized expression builder architecture
- Modernized configuration API with smart defaults
- Improved connection pool management
- Better type safety through Crystal's type system
- Clearer CQL-specific compile-time errors for malformed relationship macros

### Deprecated

- `cascade` parameter in relation collections (use `dependent: :destroy` instead)
  - Affects: `Collection` and `ManyCollection` classes
  - Migration: Replace `cascade: true` with `dependent: :destroy`
  - Will be removed in: v1.0.0

### Removed

- Unused backup code in `src/expression/expressions_backup.cr`

### Fixed

- Subqueries (`IN (SELECT ...)`, `EXISTS`, `INSERT ... SELECT`) no longer discard the parameters bound by the enclosing query (SELECT, UPDATE and DELETE), and PostgreSQL `$n` numbering now continues across them.
- Multi-row `INSERT` on PostgreSQL numbers each row's placeholders (it emitted `($1,$2),($1,$2)`); rows are aligned by column name and rows with a different column set raise `ArgumentError`.
- `OFFSET` without `LIMIT` is no longer dropped (bare `OFFSET` on PostgreSQL, `LIMIT -1` on SQLite, maximum `LIMIT` on MySQL).
- Block DSL qualifies columns with the table alias (`from(customers: :c).where { c.city == ... }`).
- `Update#where` / `Delete#where` AND with earlier conditions instead of replacing them.
- `QueryBuilder#having` builds a `HAVING` clause (it called `where`); `reverse_order` and `unscope` work; aggregates, `ids` and `reorder` no longer alter the builder they are called on.
- `mysql://` URIs are accepted by `Schema` (an empty host is rejected).
- `QueryBuilder#pick` no longer alters the builder it is called on; `Model.having` accepts implicit-self blocks.

- Connection pool configuration consistency
- Transaction rollback handling
- Error context in exception messages

### Security

- DDL identifiers that cannot be bound as parameters are now validated: index, foreign key, unique/check constraint names, rename targets and foreign key table/column names must match `[A-Za-z_][A-Za-z0-9_]*` (`DROP INDEX` also accepts one `schema.` qualifier). Anything else raises `ArgumentError` instead of being spliced into SQL. Names with other characters (hyphens, dots, spaces, non-ASCII) previously produced broken unquoted SQL.
- Aggregate aliases (`count(:id, as: "n")`) are validated the same way.

- SQL injection prevention in query builder
- Parameterized query support
- Prepared statement usage by default

## [0.0.435] - Current

### Summary

Current stable release with comprehensive ORM functionality.

## Migration Guide

### Upgrading from v0.x to v1.0

#### Deprecated `cascade` Parameter

**Before (v0.x):**

```crystal
has_many :posts, foreign_key: :user_id, cascade: true
```

**After (v1.0):**

```crystal
has_many :posts, foreign_key: :user_id, dependent: :destroy
```

**Dependency Options:**

- `:destroy` - Destroy associated records (runs callbacks)
- `:delete_all` - Delete associated records (no callbacks)
- `:nullify` - Set foreign key to NULL (default)
- `:restrict` - Prevent deletion if associations exist

## Version History

For detailed version history, see [GitHub Releases](https://github.com/azutoolkit/cql/releases).

---

## Contributing

When adding entries to this changelog:

1. Add new changes under `[Unreleased]` section
2. Use the following categories: Added, Changed, Deprecated, Removed, Fixed, Security
3. Write changes from user perspective (what changed, not how)
4. Link to relevant issues/PRs when applicable
5. Update migration guide for breaking changes

## Version Numbering

- **Major version (X.0.0)**: Incompatible API changes
- **Minor version (0.X.0)**: New functionality in backward-compatible manner
- **Patch version (0.0.X)**: Backward-compatible bug fixes
