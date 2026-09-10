# S1 queued order-processing checkpoint

Date: 2026-09-10. [PR #17](https://github.com/zemeng2015/commerce-event-ledger/pull/17) implements [issue #9](https://github.com/zemeng2015/commerce-event-ledger/issues/9). Verified implementation head: `95d33e26e8ea077943a20211dbc159e8742e7845`.

## Evidence

[Application CI 34500652694](https://github.com/zemeng2015/commerce-event-ledger/actions/runs/34500652694) and [Foundation CI 34500652692](https://github.com/zemeng2015/commerce-event-ledger/actions/runs/34500652692) passed on that head.

| Check | Observed result |
| --- | --- |
| Native MySQL 8.4.11 | 128 tests, 2,026 assertions; zero failures, errors, or skips |
| Fresh Docker MySQL 8.4.11 | Same 128 tests and 2,026 assertions; zero failures, errors, or skips |
| Full-suite source coverage in both environments | 206/226 branches (91.15%), 750/768 lines (97.66%); all 36 application/package/library files loaded |
| Real asynchronous order-create demo | Ten signed deliveries reached `processed`, one canonical event, one effect, and one projection transition |
| Worker startup repetition | Twenty graceful jobs-service restarts; each new event ID received ten signed deliveries and reached one effect; every case passed |
| Canonical receipt race repetition | Twenty native runs of ten sequential and ten concurrent duplicate receipts passed |
| Boundaries and runtime | Packwerk validate/check, positive and three negative probes, Zeitwerk, and `ruby bin/jobs check` passed |
| Hygiene and security | 72 Ruby files linted without offenses; Brakeman zero warnings; updated bundler-audit found no vulnerabilities; fixture database isolation passed |

The generated [native](evidence/processing/native-coverage.json) and [Docker](evidence/processing/docker-coverage.json) summaries retain source-level measurements. CI retains raw coverage artifacts for seven days. These are overall implemented-source measurements, not certification of the separate full-release core coverage gate.

The initial fresh-stack event applies the order projection. Subsequent startup cases use distinct canonical event IDs for the same fixture order and equal source timestamp; they record stale effects while retaining the single projection transition. Twenty graceful restarts do not substitute for the required forced process termination and full duplicate/crash/out-of-order stability suite.

## Accepted behavior and review findings

Active Job uses the locked Solid Queue 1.7.0 adapter and primary MySQL connection. Enqueue occurs after receipt commit; a real queue-table constraint failure leaves the committed event pending and eligible for scheduled recovery. Invalid signatures and failed receipt transactions enqueue no work.

EventLedger commits tenant-scoped claims and attempts before calling Orders. Orders locks the projection and commits its update with the unique handler effect. A real effect-table constraint failure rolls back both projection and effect. Duplicate execution observes the original effect. Tenant composite foreign keys reject forged cross-tenant associations. Older or equal nanosecond source times record stale outcomes without moving the projection backwards.

Lifecycle acknowledgment happens after the effect transaction. A replaced claim cannot acknowledge or fail the newer owner. Bounded handler failures reach dead letter. Clock-advanced lease recovery after an unacknowledged effect retains one effect and one projection transition; this is not a real process-kill experiment.

Review found plaintext claim values in MySQL debug SQL. The implementation now stores only SHA-256 token digests; raw tokens remain in the executing claim object and are absent from SQL diagnostics and default serialization. The migration hashes prior values without reading them into Ruby diagnostics and is intentionally irreversible.

The asynchronous verifier initially observed a stale Rails runner query-cache snapshot even though worker logs proved successful commits. Polling now uses uncached database reads. The corrected verifier passed the initial demo and all twenty restart cases without extending its 30-second deadline. Failure output contains only state and queue counts, not tokens or bodies.

No gem dependency was added. Solid Queue's existing checksum-verified schema template is included as an ordinary migration, with its MIT notice. The actual MySQL-generated schema is committed. Local Windows verification used Ruby syntax, repository checks, and `git diff --check`; runtime results came from native MySQL CI and fresh Docker.

## Next dependency and limits

Implement tenant-scoped GraphQL event status in [issue #10](https://github.com/zemeng2015/commerce-event-ledger/issues/10), then package the repeatable developer demo in #11. See the [processing contract](processing.md) for queue placement, retry/lease policy, and commands.

S1 remains in progress. Updated/cancelled topics, real forced-crash experiments, 100 sequential/concurrent duplicate-delivery evidence, the full 20-run failure suite, audited replay, production-quality observability, actual development-store integration, clean-clone timing, benchmark, and releases remain required. This checkpoint does not complete the v0.1 goal or establish production readiness.
