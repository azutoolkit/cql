# CQL v1 release review

This work continues PR #65 at `d393ce94595bedf012a58c363128dd46863a5a62`, on its existing
`claude/sharp-galileo-ygjvv3` branch. The PR changes 139 files relative to master, adding roughly 5,433 lines and
removing 577. Its native driver, most advanced SQL constructs, relation macros and telemetry infrastructure
already existed; the PR primarily hardens their failure and transaction behavior. Master through
`8cd475f7ae8f3d0bb1cb0976f310dcb8993c5a1b` is merged in `1356dae`, preserving the newer per-request
fiber cache isolation used by Azu; the source manifest now matches master at 0.0.925.

## Audit and changes

| Area | PR #65 foundation | Gap and response |
| --- | --- | --- |
| Connect/TLS/protocol | One checkout deadline across queue/health/connect, query cancellation, protocol 3.2/3.0 fallback, client certificates, `verify-full` | Pool shutdown could admit a connection completing after close: two failing regressions now covered. COPY format vectors and trailing backend bytes were insufficiently validated: strict parsing and a seeded 2,000-input corpus added. |
| Pool recovery | Dead idle connections are detected; sent statements are never blindly replayed; reset hooks support `DISCARD ALL` | Added opt-in connection circuit breaking, stale-attempt generation guards and one half-open probe. Disabled by default; no SQL replay. Application admission control is still necessary. |
| Streaming/pipelines | Session locking, fiber-owned streams, portal cleanup, bounded fetch batches, bounded request batches | Added four-thread stress with 64 workers sharing four connections, pipeline errors between successful results, early stream termination and lease accounting. Pipeline results remain materialized: use streaming for large results. |
| Telemetry/integration | Query and transaction events, pool wait, context, async bounded queue, tracer, plan analysis and EngineSource | Repeated tracer invocation could duplicate a write. Added a guard and regression. No automatic EXPLAIN ANALYZE is added: it executes SQL and must remain an explicit application policy. |
| Migrations/schema | PostgreSQL advisory locking, lock timeout, duplicate-version rejection, rollback state, safe schema dump, post-commit file sync | Existing migration concurrency and transaction tests are release checks. MySQL/CockroachDB DDL is not transactional; concurrent deploy migrators there require external serialization. Schema-file sync failure after commit is reported and cannot undo committed DDL. |
| DSL/macros/relations | Literal string predicates, typed columns, relationship diagnostics; existing CTE/recursive/window/JSON/geo SQL | Added a reproducible seeded compiler corpus for PR #65 predicates and malformed relation declarations, alongside advanced SQL and compile-time guardrail suites. Four stale pending QueryBuilder cases now execute HAVING and inner/left/right joins against real data, including unmatched rows. This is bounded testing, not an exhaustive proof for arbitrary generated programs. |
| Locking/isolation | Stale-update/delete rejection, rollback hooks, explicit isolation, savepoints and serialization retry helper | Added a live four-dialect contract. SQLite rejects read committed; CockroachDB can strengthen it. Retries must include the whole safe transaction and cannot encompass external side effects. |
| Diagnostics/allocations | Bounded N+1 patterns, opt-in monitor, zero-allocation instrumentation budgets | Added optional first-detection backtraces. Default capture stays off; synchronous monitoring is needed for the caller's stack. Existing allocation tests are gates; whole query builders and row arrays are not claimed allocation-free. |

## Reproduce validation

Use Crystal 1.22.1 and install the declared shards. CI also checks the supported floor, Crystal 1.19.1.
Start disposable databases only; the dialect contract creates and removes `cql_v1_records` in the supplied database.

```sh
crystal spec
DATABASE_URL=postgres://postgres@127.0.0.1/cql_test CRYSTAL_WORKERS=4 \
  crystal spec -Dpreview_mt validation/native_stress_spec.cr spec/postgres/pool_shutdown_spec.cr spec/postgres/circuit_breaker_spec.cr
CQL_ENTERPRISE_DIALECT=sqlite CQL_ENTERPRISE_URL=sqlite3:///tmp/cql-v1.db \
  crystal spec validation/dialect_spec.cr
python3 script/macro-fuzz.py --seed 65 --cases 64
```

For the other dialects, set `CQL_ENTERPRISE_DIALECT` to `postgres`, `mysql` or `cockroach` and
`CQL_ENTERPRISE_URL` to the disposable database URI. Missing servers fail the contract; they do not become pending.
The reusable `.github/workflows/enterprise.yml` defines the services, TLS probes and complete release selections.
The main release job requires it and the crystal-db compatibility workflow.

## Validation record

- Original PR baseline on Crystal 1.22.1 with PostgreSQL 17: **3,454 examples, zero failures/errors, 19 pending**.
  Four were stale QueryBuilder tests; the others needed pooler, server-version, TLS or dialect-specific fixtures.
- Original pool shutdown regressions: **2 failures**; patched pool shutdown/circuit/stress selection: **9 passed**
  under four threads on each of PostgreSQL 14, 17 and 18. The stress case runs 64 workers × 5 pipeline/stream cycles.
- PostgreSQL 14 and 18 expanded selections: **133 passed each**, zero pending, covering real queries, cancellation,
  failover and migration locking as well as protocol checks. Disk-exhaustion failures during the initial matrix
  attempt were resolved by removing unused fixtures and moving build caches; these counts are the completed reruns.
- Seed 65 compiler corpus: **64 valid predicate expansions and 5 negative macro cases passed**.
- Live SQLite, PostgreSQL 17, MySQL 8.0 and CockroachDB 24.3 contracts: **4 passed each**, zero pending.
  MySQL uses the native-password server default and performance_schema transaction instrumentation to verify the
  active isolation level (the session default variable does not report one-transaction overrides).
- PostgreSQL TLS probes: all passed, including trusted CA, wrong hostname, missing CA, required TLS refusal and
  non-retryable TLS errors. The full suite also enabled encrypted-blackhole checks against the TLS fixture.
- Focused N+1, allocation and driver selection: **56 passed**. Tracer/protocol selection: **86 passed**.
- QueryBuilder selection after replacing the four pending cases: **138 passed**, zero pending.
- Final merged-branch full suite with PostgreSQL 17 and TLS: **3,478 examples, zero failures/errors, 12 pending**
  in 2 minutes 41 seconds. The pending cases require optional PgBouncer (10), version-matrix (1) or CockroachDB
  binary-parameter (1) fixtures; the separate live dialect and PostgreSQL matrix selections above passed.
- Ameba: **389 files, zero failures**; Crystal formatting and diff checks passed. Documentation checks covered
  **107 Markdown files** and **90 GitBook pages** without errors; both changed executable documentation programs compiled.

Logs are retained in the prepared environment under `/workspace/setup/logs/cql-*`. The hosted compiler and release
matrix still need to pass on the reviewed commit.

## Release and deployment gates

### Follow-up blocking review of `184714e`

The successful local matrix did not establish v1 readiness. A subsequent review and the supplied hosted CI log
identified these gaps. Evidence logs and standalone probes are retained under `/workspace/setup/logs/cql-review-*`
and `/workspace/setup/cql-review/` in the prepared environment.

| Priority | Finding | Evidence and required action |
| --- | --- | --- |
| P1, corrected | PostgreSQL fixture opens before the integration-test guard | The supplied CI log aborts in `InsertFailureDB` initialization with `DB::ConnectionRefused` at localhost:5432. The compiler-floor job intentionally has no server. The fixture is now constructed after `require_postgres!` and closed in `ensure`; both database-free and live paths passed locally as recorded below. Deprecation warnings are unrelated. |
| P1 | The release can publish the wrong major/version after merging | The pinned `paulhatch/semantic-version@v4.0.2` with `bump_each_commit: true` was run against local merge simulations using this branch's history and the verified `v0.0.925` base. Current head computes 1.0.0; an ordinary merge computes 1.0.1; a merge containing `(MAJOR)` computes 2.0.0; a single `(MAJOR)` squash computes 1.0.0. The workflow immediately calls `script/release` without asserting the intended version. Require the intended version before publication and use a verified single-squash release or revise the versioning policy. |
| P1 | Checkout setup bypasses the remaining deadline | `Pool#open` passes the deadline to `Connection.open`, then calls `setup` without it. A real PostgreSQL setup query `SELECT pg_sleep(0.25)` succeeded after 254 ms with `checkout_timeout=0.05`. Bound setup SQL by the remaining checkout budget and discard timed-out connections before admission. The circuit breaker cannot recover a setup attempt that never completes. |
| P1 | A transaction scope can outlive its lease across fibers | `TransactionScope#exec_query` checks `@finished` only before yielding; it has no owner check or active-operation lifetime guard. A child fiber entered the scope, paused, and resumed after the outer transaction returned the connection. It read the next borrower's `application_name`. Reject foreign-fiber scope use or retain the lease until all admitted operations complete. Existing sequential escaped-scope tests do not cover this interleaving. |
| P2 | Failed schema writes can destroy the previous schema file | `SchemaDump#dump_to_file` writes directly to the destination. Injecting a 1 KiB file-size limit raised `IO::Error` after replacing the previous file with 1,024 bytes of the new content. `Migrator#sync_schema_file` only logs this error despite its preservation contract. Write a sibling temporary file, flush it, and replace the destination atomically only after success; test write failure after partial output. |

The other four findings remain unresolved by the CI-fixture correction. Treat them as release-review blockers,
not as passed scenarios covered by the earlier stress or migration checks. The crystal-db compatibility script
passed independently for 0.13.1, 0.14.0, 0.15.0 and latest; that check is compilation, not a live dialect test.

The fixture correction was validated with the actual supported floor, Crystal **1.19.1**: **3,478 examples,
zero failures/errors, 135 pending**, with PostgreSQL deliberately unavailable. Those pending server/optional-fixture
cases do not count as integration passes. On Crystal 1.22.1 with PostgreSQL 17, the insert selection passed **11
examples with no pending cases**. Changed-file lint, formatting and documentation links passed. Hosted CI still
needs to rerun on the corrective commit.

### Remaining publication and application checks

- Review the final PR commit and pass hosted CI, including every new required job. GitHub API access is currently
  denied in this environment; native Git access works. The supplied hosted log confirms the fixture failure above;
  no subsequent hosted pass, approval or release is asserted here.
- The existing release workflow owns `shard.yml`, changelog, version commit, tag and GitHub release. With its
  current per-commit versioning policy, use a single reviewed squash containing `(MAJOR)` for this initial v1
  release and verify that the computed version is exactly `1.0.0` before publication. A normal merge retaining
  the branch's existing major-bump commit over-bumps, even more if its merge message also contains `(MAJOR)`.
  This corrects the earlier recommendation to preserve the marker with either merge strategy. Adding tests is
  not authorization to bypass review or CI.
- Validate the actual application's TLS/proxy topology, database privileges, migration serialization, failover,
  backups/PITR, workload/SLO and telemetry export. Single-node transactional tests cannot establish distributed
  durability, cross-region recovery or a production capacity limit.
- MySQL's external driver has authentication limitations documented in the database support guide. PostgreSQL
  geo operators also require PostGIS; SQL generation tests do not prove that extension is deployed.
