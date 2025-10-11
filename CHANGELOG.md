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
- **New API methods for consistency (v0.0.436+)**:
  - `Query#get!` - Raises exception if scalar value not found (matches `first!` pattern)
  - `Query#where_null(field)` - Explicit IS NULL condition for better clarity
  - `Query#where_not_null(field)` - Explicit IS NOT NULL condition for better clarity

### Changed

- Improved error handling with detailed exception hierarchy
- Enhanced N+1 query detection with better pattern recognition
- Optimized expression builder architecture
- Modernized configuration API with smart defaults
- Improved connection pool management
- Better type safety through Crystal's type system

### Deprecated

- `cascade` parameter in relation collections (use `dependent: :destroy` instead)
  - Affects: `Collection` and `ManyCollection` classes
  - Migration: Replace `cascade: true` with `dependent: :destroy`
  - Will be removed in: v1.0.0

### Removed

- Unused backup code in `src/expression/expressions_backup.cr`

### Fixed

- Connection pool configuration consistency
- Transaction rollback handling
- Error context in exception messages

### Security

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
