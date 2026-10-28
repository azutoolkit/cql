| 1 | 7a65ad0 | +107 | review approve, security approve, perf approve (minors applied) |
| 2 | 82b58ea | +77 | review approve; security request_changes x2 -> approve; perf approve (post-commit, minors only) |
| 3 | c656c4d | +35 | review approve, perf approve, security request_changes (wording; UNIQUE not guaranteed) -> folded into slice 4 + new slice 4c |
| 4 | f390ca6,d03fb02,434c534 | +243 (3 commits) | request_changes x2 -> confirmation: code-reviewer approve, security approve (wording minors -> 4d) |
| 5 | d8d7dde | +117 | review request_changes -> approve; security approve; perf approve |
| 6+7 | 27f6c65 | +122 | review major + security request_changes -> fixed, re-review approve; perf approve |
| 4c | ed52116 | +95 | review/security/perf approve (minors applied) |
| 4b | 029c91f | +66 | review approve; sec/perf approve (no-op boot N=200: 801 stmts/141ms -> 2/2.4ms); wording minors -> 4d |
| 4d | 195e380,1fff0b6 | +178 (2 commits) | review+security request_changes (restore spec) -> fixed, re-review approve |
| 8 | 40e2a2c | +51 | review approve, security approve (follow-ups 8b, 8c) |
| 9+10 | 21a99e0 | +73 | review approve; security approve (follow-up 10b) |
| 9b | 1a2b174 | +66 | review approve; security request_changes (2nd-order injection) -> slice 9c |
| 10b | 43a62b6 | +102 | review approve; security BLOCKER (; separator bypass introduced by orchestrator minor fix) -> slice 10c |
| 9c | f9a23c1 | +147 | review request_changes -> approve; security approve (injection closed; minors -> 9d) |
| 10c | 470971d | +22 | review approve; security approve (blocker closed, live PG) |
| 12 | fbdffb3 | +102 | review major + security blockers -> reset_all removed; both re-reviews approve |
| 11 | a306dd4 | +51 | review approve; security approve after commit (35 live probes clean; minors -> slice 8b: driver.cr pg-shard comment, telemetry doc) |
| 13 | 6d608e3 | +127 | review approve; perf approve; security BLOCKER (NUL truncates SQLite pattern) -> fixed, both re-reviews approve |
| 8b | f9e63ac | +51 | review approve; perf approve; security approve (minor: cause note added; scopes.cr -> slice 8d) |
| 8d | 675c4ae | +24 | review approve (after ScopeError rename); perf approve; security approve |
| 8c | 1ec0cf1 | +89 | review approve; perf approve; security approve (live PG native+pg shard+SQLite; predating minor deferred) |
| 9d | 12bf9bc | +62 | review approve; perf approve; security request_changes (2 pre-existing blockers -> 9e) -> minors applied, confirmation approve |
| 9e | e7c5001 | +110 | review approve; perf approve; security major (CockroachDB full-Unicode fold) -> fold_unquoted_name hook, both re-reviews approve |
| M2 docs | 857c4e8 | docs | docs-only (exempt) |
| 14 | 7e7ec5c | +130 | review request_changes -> approve; security request_changes -> approve (pg shard ignores key: warning + docs); perf approve (+0-2% set, none unset) |
| 14b | 281c803 | +90 | review approve (+delta confirm); perf approve (-64 B/stmt unset); security approve (minors applied) |
| 15 | e8cfe16 | +112 | review approve (+non-live spec); perf approve (+0.24us/checkout); security approve (live TLS/plain/unix; crystal-db retry duplicate-write found -> slice 16a) |
| 16a(+16) | fced483 | +136 | review approve (+delta); perf approve (225ns/checkout); security approve (live repro: 8/8 duplicate writes gone) |
| 16b | b151a4b | +127 | review approve (+delta); perf approve; security approve (live: no double execution on any CQL path) |
| 17 | 5fd8b87 | +109 | review approve (+2 deltas); security major (@ in password leaked into host) -> fixed, approve; perf skipped (error path) |
| 18 | 6f44894 | +145 | review request_changes -> approve; perf approve; security request_changes (3 fixed; per-read vs total -> slice 18c, docs corrected) |
| 18c | 533e07e | +96 | review approve; perf approve (<1ms/connect); security approve (slow-drip ~1.0s, 2000 race connects 0 broken; DNS/multi-address deferred) |
| 18b | 9ddd778 | +149 | review/security/perf request_changes (shared health-check half; 48B/query alloc) -> fixed, all three approve |
| 18d | 30de5f0 | +113 | spec-only; review approve (tolerance widened to 0.3 s) |
| 19 | 5779063 | +149 | review approve (+re-review); perf approve; security major (64KiB scan bypass -> tty prompt) -> passwd cb fix, approve (live cert auth) |
| 19b | 89d8ef9 | +84 | review approve (+delta re-review of minors); security approve (libpq rule verified, 2 deferred); perf skipped (parse-time only) |
| 20 | 5f405a8 | +134 | review approve (+delta re-review); security approve (live PG16: 3 paths, poolers, server refusal rolled back); perf skipped (nil fast path) |
| 21 | 8c9ef5e | +141 | review approve (+delta); security approve (BEGIN-failure leak -> close + spec; override note); perf skipped (MySQL-only path); orchestrator kept transaction(&) overridable + regression spec |
| 22 | aee8dbf | +136 | review approve; security request_changes (docs overstated read-only: major) -> docs/CHANGELOG reworded + live routed writes, approve; fail-closed guard split to 22b (budget); container restart lost one security run (rerun) |
| 22b | 27a780d | +26 | review approve; security approve (blank statement -> .presence, re-approved) |
| 23 | 852ce6f | +59 | review approve; security request_changes (model override/previous_def broken: major) -> separate keyword overloads + spec, approve |
| 24 | 6f8ddba | +150 | review approve; security escalate (retry re-runs record state: silent lost write; tx.commit duplicate; COMMIT-time 40001 poisons connection) -> docs now, 24b/24c/24e split, 24d by user decision Q10 (reset + raise); re-review approve |
| 24b | 0ae6fcc | +42 | review approve (+delta); security approve (raw COMMIT SQL undetected -> docs + deferred) |
| 24c | 05bcd81 | +41 | review approve; security approve (live: SSI at commit, timeout, cancel, FATAL, 40P01/40003) |
| 24e | 55ffdbc | +39 | review approve; security approve (live: no false positive/negative, pipeline slot, exec_all, copy_in; all paths reusable) |
| 24d1 | 80f1d05 | +150 | code request_changes (40003) -> approve; security request_changes (return/break, 08 pooler FATAL) -> classification fixed, approve; rest split to 24d1b/24d1c before 24d2 |
| 24d1b | fd081dc | +99 | review request_changes (telemetry guard untested) -> spec + mutation check; security approve (live proxy: return/break/nested, all earlier cases, telemetry once) |
| 24d1c | 26947c3 | +115 | review approve (+delta); security blocker (close half-fails on SQLite -> SIGSEGV) -> release flag instead + crash spec, approve; container restart mid-review |
| 24d2 | 5d21b62 | +106 | review approve; security approve (live: no duplicate rows across all 24d cases; resets still happen; raw COMMIT SQL documented/deferred) |
| 24f | c6b53c6 | +124 | code request_changes (stale spec) -> fixed; security request_changes (MySQL snapshot read; false positives on matched-rows dialects) -> check on every 0 with FOR UPDATE, approve (live MariaDB/PG/SQLite) |
| 24g | 98cb44c | +73 | review approve; security request_changes (rolled-back restore!+delete! hid a committed soft delete; save! undeleted) -> restore! hook + exact destroyed, approve |
| 24h | 0bfa438 | +31 | review approve; security approve (live: no lost update; hook-order gap -> 24i; memory deferred) |
| 24i | 3d7c2ef | +68 | code request_changes (hand_to self-loop; nested savepoint after release) + security request_changes (same) -> settled_frame at every entry + self-guard, both approve (live PG); sp.rollback hooks deferred |
| 25 | 0e96ea3 | +89 | code approve (minors: upgrade note, UUID spec, actual-only text -> fixed); security request_changes (missing Upgrade note) -> added, approve; id-in-message sites outside locks deferred |
| 26 | 1ca37ab | +67 | code approve (minor: PG pin -> added); security approve (live PG: second commit raised PQError on HEAD; minors: resolution spec, row read-back -> added; double SET with set(version:) deferred); full suite 3437 on identical src |
| 26b | 172efa5 | +143 | code request_changes (rolled-back clear left the collection empty: retry orphaned targets) + security request_changes (same; Through.schema hung/locked on split schemas) -> all_or_none on Target.schema + reload hook, split over budget (:delete_all paths and split-schema spec -> 26b2), both approve (live PG) |
| 26b2 | 6024d28 | +85 | code approve (minors: temp file, ids window -> kept); security approve (live PG: refused DELETE rolls back, split schema with FK no hang; minor: temp file leaked when filtered -> after_suite, approve) |
| 26c | 9578993 | +139 | code approve; security approve (live PG: 3 racing migrators identical to HEAD); both minors (new public types) -> private struct, applied verbatim, gates green, no re-review; full suite 3445 |
| 27 | d9bb0bd | +137 | v1: code approve; security escalate (concurrent CONCURRENTLY deadlock / INVALID index recorded -> user: take turns, slice 27a), CI blocker, ordering regression -> v2 fixed; v2 security request_changes (stale CHANGELOG lock entry + run-migrations how-to) -> v3 docs + record-step prefix check, both approve; suite interference from reviewer runs (shared temp SQLite) -> clean rerun 3450 |
