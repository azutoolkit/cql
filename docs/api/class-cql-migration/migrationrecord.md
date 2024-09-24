# MigrationRecord

## class CQL::Migrator::MigrationRecord

`DB::Mappable` < `DB::Serializable` < `Reference` < `Object`

Represents a migration record. @field id \[Int64] the migration record id @field name \[String] the migration name @field version \[Int64] the migration version @field created\_at \[Time] the creation time @field updated\_at \[Time] the update time **Example** Creating a migration record

```crystal
record = CQL::MigrationRecord.new(0_i64, "CreateUsersTable", 1_i64)
```

## Included Modules

`DB::Mappable`, `DB::Serializable`

### Constructors

#### def new`(id : Int64, name : String, version : Int64, created_at : Time = Time.local, updated_at : Time = Time.local)`

#### def new`(rs : DB::ResultSet)`

### Class Methods

#### def from\_rs`(rs : DB::ResultSet)`

### Instance Methods

#### def created\_at

#### def id

#### def name

#### def updated\_at

#### def version
