---
title: "Cql::Migrator::MigrationRecord"
---

# class Cql::Migrator::MigrationRecord

`DB::Mappable` < `DB::Serializable` < `Reference` < `Object`

Represents a migration record.
@field id [Int64] the migration record id
@field name [String] the migration name
@field version [Int64] the migration version
@field created_at [Time] the creation time
@field updated_at [Time] the update time
**Example** Creating a migration record

```crystal
record = Cql::MigrationRecord.new(0_i64, "CreateUsersTable", 1_i64)
```

details Table of Contents
[[toc]]

# Included Modules

`DB::Mappable`, `DB::Serializable`

## Constructors

### def new`(id : Int64, name : String, version : Int64, created_at : Time = Time.local, updated_at : Time = Time.local)`

### def new`(rs : DB::ResultSet)`

## Class Methods

### def from_rs`(rs : DB::ResultSet)`

## Instance Methods

### def created_at

### def id

### def name

### def updated_at

### def version