# Roadmap

Status: S0 complete; S1 in progress. Signed HTTP receipt and canonical MySQL storage are accepted; queue processing, order effects, and status queries remain pending. Stages are acceptance gates, not automatic calendar deadlines. The original four-week sketch is an estimate for planning; development proceeds according to evidence and available integration access. See the [foundation checkpoint](bootstrap-checkpoint.md), [scaffold acceptance](s1-scaffold-checkpoint.md), [package acceptance](s1-package-checkpoint.md), and [current development setup](development.md).

The project follows the [charter](project-charter.md) and [long-term goal](long-term-goal.md). Only Commerce Event Ledger is in scope.

| Stage | Deliverable | Exit evidence | Current status |
| --- | --- | --- | --- |
| S0 — Foundation | Repository, MIT license, contributor and security guidance, charter, architecture, goal, and a focused first backlog | Documentation reviewed; repository prepared for development; planned checks distinguished from runtime checks | Complete; Foundation CI passed and initial backlog created |
| S1 — First vertical slice | Rails API/MySQL setup, four package boundaries, signed order-create fixture, HMAC ingress, canonical-event constraint, job, order projection/effect, and event query | Clean-clone demo; ten duplicate deliveries yield one canonical event and one database domain effect; MySQL-backed CI; evidence for a `v0.0.1` release | In progress; signed HTTP receipt and canonical storage accepted; asynchronous order projection/effect processing next |
| S2 — Failure and recovery | Effect transaction proof, bounded retry, dead-letter, recovery, concurrency/crash tests, and explicit out-of-order transitions | 100 sequential and 100 concurrent duplicates produce one effect; acceptance/enqueue-gap and post-effect-crash recovery pass; add updated/cancelled topics only after S1 | Not started |
| S3 — Integration and operations | Real development-store receipt, tenant-scoped GraphQL inspection and audited replay, JSON logs, traces, metrics, failure/load harness | Redacted real signed-webhook evidence; tenant and redaction checks; trace an event across receipt, attempts, and effect; benchmark environment and raw output | Not started |
| S4 — Evidence-backed release | Threat model, resolved ADRs, failure matrix, clean-clone rehearsal, demo, security/coverage/stability gates, contributor issues, and `v0.1.0` | All charter correctness and engineering gates pass; performance targets reported honestly; release artifacts cite reproducible evidence | Not started |

## S1 implementation sequence

This is the immediate development backlog. Implementation should keep the order-create path small enough to inspect end to end.

1. Scaffold the Rails API and MySQL local environment; verify supported dependencies and commit exact runtime versions and a lockfile.
2. Establish MySQL-backed CI with meaningful application tests, lint/security checks, coverage instrumentation, and zero Packwerk violations.
3. Define the four package public interfaces and the minimum schema for shops, canonical events, attempts, effects, and order projections.
4. Add synthetic order-create fixtures and a publisher that signs the exact request body, with no real customer data or embedded credentials.
5. Implement raw-body HMAC verification and sanitized normalization; invalid signatures return `401` without accepted-event persistence.
6. Implement the canonical-event unique constraint and duplicate-delivery accounting, including race-safe insert-or-find behavior.
7. Configure Active Job/Solid Queue and implement an order-create handler whose projection and effect record commit together in MySQL.
8. Add a tenant-scoped GraphQL event-status query with bounded pagination and redacted output.
9. Make the first offline demo reproducible: ten identical signed deliveries, one canonical event, one effect, and a visible final state.
10. Review the demonstrated limitations and prepare the first `v0.0.1` release evidence. A planned tag is not a published release.

Do not add a second event topic until the ten-delivery demonstration passes. S1's narrow passing demonstration does not establish the full v0.1 guarantees; S2 must test recovery and adversarial concurrency explicitly.

## Later backlog

S2 must test the database commit/enqueue gap, worker termination before and after effect commit, bounded retry exhaustion, lease expiry, duplicate workers, and non-regression under out-of-order events. Use MySQL constraints and transactional tests to establish correctness. Review [ADR-0002](adr/0002-acceptance-and-recovery.md) against experimental results before accepting its implementation details.

S3 adds the operations surface only after the core pipeline is inspectable. Replay needs tenant authorization, a required reason, immutable audit records, and unchanged event/effect identity. A real development-store webhook is a required v0.1 integration gate; if store access is unavailable, continue independent offline work and retain that gate as pending.

S4 records at least 90% core and 80% overall branch coverage, 20 consecutive stable runs of the duplicate/crash/out-of-order suite, security scan output, a fresh-clone demo rehearsal, and a documented 100 RPS / 60-second experiment. The latency numbers remain targets until measured. Publish unfavorable measurements alongside favorable ones.

## Scope and stop rules

- Keep at most two implementation issues in progress, with acceptance evidence attached to each change.
- If the order-create path is unstable, prioritize correctness over additional topics, replay conveniences, dashboards, or infrastructure.
- Do not add Redis, Kafka, a custom outbox, or service boundaries to conceal a missing failure model. An outbox change requires an ADR and evidence of a specific gap in the initial recovery design.
- Do not relax database idempotency, crash recovery, tenant isolation, redaction, MySQL-backed checks, or honest documentation to meet a calendar estimate.
- No tag, external deployment, or release milestone is complete merely because its planned date has arrived.

## Next action

Implement Active Job/Solid Queue processing and the transactional Orders projection/effect in issue #9, following the [accepted HTTP and canonical receipt](s1-receipt-checkpoint.md). Then add tenant-scoped status queries (#10) and the ten-delivery/one-effect demo (#11). Receipt-only concurrency evidence does not complete S1 or the overall goal.
