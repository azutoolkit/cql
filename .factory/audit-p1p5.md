# Audit P1/P5 (summary of agent report)
S1.1 partial (many clear macro errors exist). S1.2 partial: SchemaValidator vs declared schema only, opt-in CQL_VALIDATE_SCHEMA_MAPPINGS=1, runs at_exit; no live DB check, no boot strict mode.
S1.3a exists (CTE/recursive/window/set ops; $n numbering correct in 7 combos). Minor: CTE SELECT-only, no MATERIALIZED, compound no order/limit.
S1.3b exists/partial: upsert yes; JSON only json_eq/json_contains; geo only within_distance; raw fragments WHERE only.
S1.3c missing: no polymorphic, no has_many through:.
S5.1 partial; S5.2 partial: tx per up on PG/SQLite; no lock, no irreversible guard, no expand/contract helpers.
Confirmed gaps:
1 No migration lock: two processes both apply data migration (n=2, 1 row). Fix advisory lock (pg_advisory_xact_lock / GET_LOCK) + recompute pending after lock.
2 MySQL rename_column/change_column (CHANGE/MODIFY) drop NOT NULL + DEFAULT (mysql_dialect.cr:103,110).
3 Property without column silently not saved (insertable.cr:109), validator doesn't flag.
4 default: "CURRENT_TIMESTAMP" on Time columns other than created_at/updated_at quoted as string (generator.cr:37,655): SQLite stores text, PG fails 22007.
5 Duplicate migration versions corrupt state -> raise in Migrator.new.
6 auto_sync default on: writes schema file with URI incl password (schema_dump.cr:83); raises after commit if unwritable.
7 MySQL text -> VARCHAR(255) (cql.cr:106).
8 No disable_ddl_transaction! (CREATE INDEX CONCURRENTLY fails, rolls back batch).
9 Empty down passes silently; no IrreversibleMigration.
10 has_one lacks FK checks has_many has (model.cr:124).
11 db_context to unknown table compiles, KeyError at runtime.
12 column :x, Int16 compiles, KeyError at create_sql.
13 Unclear errors for unsupported assoc options (join_through: symbol, has_many through:).
14 Validator only at program end; no boot call.
Minor: SQLite RETURNING refused though 3.35+; rolled back migration leaves schema.table in memory; migration_applied? reruns CREATE TABLE IF NOT EXISTS.
Suspected: MySQL/Cockroach partial migration; CRDB ALTER TYPE; PG identity explicit ids; raw tokenizer backslash quote; SQLite like case-insensitivity; schema file URI not escaped in string literal (code injection via password with #{).
