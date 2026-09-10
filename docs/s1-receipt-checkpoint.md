# S1 HTTP and canonical receipt checkpoint

Date: 2026-09-10. [PR #16](https://github.com/zemeng2015/commerce-event-ledger/pull/16) merged as `5e10ec52e4af2ac2a18a64fca939a1ce0da8503e`, completing issues [#7](https://github.com/zemeng2015/commerce-event-ledger/issues/7) and [#8](https://github.com/zemeng2015/commerce-event-ledger/issues/8). Verified implementation head: `42c6615f7b6143169aaa139115f1e4c340be9a8a`. Final documentation head `ab5a4c586f45b257343525652025f36a7ba5dc9b` also passed [Application CI 34496498871](https://github.com/zemeng2015/commerce-event-ledger/actions/runs/34496498871) and Foundation CI before merging; its tree matches the merge.

## Evidence

[Application CI 34495806797](https://github.com/zemeng2015/commerce-event-ledger/actions/runs/34495806797) and [Foundation CI 34495806743](https://github.com/zemeng2015/commerce-event-ledger/actions/runs/34495806743) passed on that head.

| Check | Observed result |
| --- | --- |
| Native MySQL 8.4.11 | 117 tests, 1,952 assertions; zero failures, errors, or skips |
| Fresh Docker MySQL 8.4.11 | Same 117 tests and 1,952 assertions; zero failures, errors, or skips |
| Canonical race repetition | 20 consecutive native runs; each checks ten sequential and ten concurrent deliveries, one row, and delivery count ten in each scenario; all passed |
| Actual Docker HTTP publisher | Ten accepted responses for the same signed 156-byte fixture; exact fixture digest retained in the CI log |
| Coverage in both full suites | 168/179 branches (93.85%), 604/613 lines (98.53%); all 27 application/package/library source files loaded |
| Boundaries | Packwerk validate/check passed; public access and all three negative enforcement probes passed |
| Runtime and security | Zeitwerk passed; 57 Ruby files linted without offenses; Brakeman zero warnings; updated bundler-audit found no vulnerabilities |
| Isolation | Fixed test database checks and unrelated-database grant denial passed; no host database was used |

The [native](evidence/receipt/native-coverage.json) and [Docker](evidence/receipt/docker-coverage.json) summaries preserve the generated measurements. Their legacy scope label predates the receipt adapter; the enumerated 27 files are the measured source. These numbers do not establish the future effect/ordering/recovery coverage gate. The 20 runs are receipt-only tests, not the full crash/out-of-order stability suite. Raw CI coverage artifacts have seven-day retention; the committed tests and source make these checks reproducible.

The generated MySQL schema was retrieved from CI after the migration ran against MySQL. No schema or database passing result was fabricated on Windows. Local verification used portable Ruby syntax checks, `python script/check_repository.py`, and `git diff --check`; the host lacks the complete Rails/MySQL runtime.

## Accepted behavior

Exact-byte HMAC verification precedes normalization and storage. Independent per-tenant route capabilities and expected server-configured shop domains prevent a shared signing secret from making a request header sufficient tenant authorization. Invalid/missing signatures, tampered bytes, and wrong tenant bindings leave no accepted event. Request limits and malformed/unsupported policies are explicit in the [HTTP contract](http-receipt.md).

The canonical unique key preserves tenant, source, and case-sensitive opaque event identity. Matching duplicates preserve the original normalized attributes and handler identity; conflicting bytes return `409`. A separate connection observes the row after `202`. A real database constraint failure after tenant insertion rolls back both writes, and enclosing transactions are rejected rather than acknowledged before commit. Nine-digit source timestamps survive storage without DATETIME truncation.

Review exposed a real concurrency failure when an existing shop no longer serialized event inserts. Retrying a whole deadlock-aborted transaction, with a maximum of five attempts, resolved it while retaining actual canonical-key competition. The stronger test was kept and passed all 20 repetitions. Parser duplicate-key diagnostics were also prevented from writing untrusted key names to stderr; the custom JSON object still rejects duplicate keys.

No dependency was added. Architecture additions are EventLedger-owned primary-connection models, `shops` and `received_events` tables, explicit Webhooks adapters, and a stable root middleware wrapper that resolves package objects inside the Rails reloader. Coverage now starts before Rails boot so that wrapper is measured.

## Remaining dependency

Implement [issue #9](https://github.com/zemeng2015/commerce-event-ledger/issues/9): Active Job/Solid Queue processing with an Orders projection and effect ledger in the same MySQL transaction. Then implement the tenant-scoped status query (#10) and the ten-delivery/one-effect demonstration (#11).

Receipts are durable pending work; no order projection or effect is produced yet. Enqueue-gap recovery, worker/process crashes, stale ordering, retries/dead letters, GraphQL replay/audit, real development-store evidence, full stability/coverage gates, clean-clone timing, benchmark, and releases remain pending. S1 and the full v0.1 goal remain active.
