# Commerce Event Ledger: project charter

Status: S1 in progress; signed HTTP and canonical receipt are implemented and tested. Queued transactional processing and initial recovery are verified in the [processing checkpoint](s1-processing-checkpoint.md); full v0.1 acceptance remains pending. This charter defines the intended complete scope; consult the [receipt checkpoint](s1-receipt-checkpoint.md) for currently verified behavior.

**Failure-aware webhook ingestion for Rails commerce applications.**

Commerce Event Ledger is a MySQL-first Rails modular monolith for accepting signed commerce webhooks, identifying duplicate deliveries, processing events asynchronously, and explaining and recovering from failure. Its primary users are Rails teams building commerce integrations and engineers examining reproducible reliability patterns.

The motivating scenario is an `orders/create` webhook delivered repeatedly while a worker crashes after committing an order projection but before acknowledging its queue job. Recovery must preserve a single database domain effect, retain the event's history, and give an operator an auditable way to inspect or replay work.

This is an independent project, not affiliated with or endorsed by Shopify.

## Seven invariants

These are design requirements. Tests and experiments must establish them before a release claims them as supported behavior.

1. An event accepted after successful HMAC verification and acknowledged with `202 Accepted` must be durably recorded and recoverable after restart; it must not silently disappear.
2. A given `(shop_id, source, external_event_id)` identifies one canonical event, enforced by a MySQL unique constraint.
3. A given `(event_id, handler_name, handler_version)` can commit at most one database domain effect. Projection changes and the corresponding effect record must share a transaction in the same business database.
4. An older event must not move an order projection back to an earlier source state. Equal or ambiguous source versions need an explicit, tested policy.
5. Every replay must record the operator, reason, timestamp, and original event association. Replay must preserve canonical-event and effect identity.
6. Logs, traces, error messages, and operator responses must not expose webhook secrets or complete sensitive payloads. Tenant boundaries must apply to ingestion credentials, reads, replay, and recovery.
7. Processing is **at least once**. The project does not promise distributed exactly-once delivery or exactly-once effects across external systems.

## v0.1 scope

- A Rails API application with MySQL as the sole business source of truth.
- A signed offline fixture publisher and a reproducible local setup.
- A Shopify development-store adapter, including evidence of at least one real signed webhook. The offline demo remains usable without a store.
- `orders/create`, `orders/updated`, and `orders/cancelled`, introduced in that order only after the first vertical slice works.
- HMAC verification, a normalized envelope, and database-enforced canonical-event deduplication.
- Active Job with Solid Queue; an order projection and handler-version effect ledger.
- Bounded retries, dead-letter handling, stale-work recovery, and a documented out-of-order policy.
- Tenant-scoped GraphQL event/order inspection and authorized, audited replay.
- Structured JSON logs, correlation identifiers, OpenTelemetry traces, and Prometheus-compatible metrics.
- Reproducible correctness, failure-injection, and load experiments, with raw results and limitations.
- English-first documentation, architecture decisions, a threat model, MIT licensing, contributor guidance, and an evidence-backed `v0.1.0` release.

## Non-goals

No storefront, catalog management, cart, payment flow, merchant order or inventory mutation, AI/LLM features, generalized workflow engine, or support for every webhook topic. Other projects are outside this repository.

No Kafka, Redis, Kubernetes, microservice split, multiple regions, custom queue, tracing backend, metrics collector, or web dashboard is needed for the first release. Do not extract a gem before repeated reuse justifies it. Do not describe the project as production-ready or claim unmeasured scale.

## Completion criteria

Every row below requires reproducible evidence. Documentation and a fixture-only implementation do not satisfy the full project goal.

| Area | Required evidence for v0.1 |
| --- | --- |
| Duplicate correctness | Deliver the same event 100 times sequentially and 100 times concurrently; each run leaves one canonical event and one domain effect. |
| Authentication | All invalid-HMAC test requests return `401`; they create no accepted event or job. |
| Ordering | Older events cannot regress the latest projection; equal/ambiguous version behavior is documented and tested. |
| Crash recovery | Kill the worker after the effect transaction commits and before job acknowledgment; restart and observe one domain effect. |
| Acceptance durability | Restart across receipt, commit/enqueue, claim, and processing failure points; every event acknowledged with `202` is recoverable with no silent loss. |
| Retry policy | Transient failures eventually succeed; exhausted or poison events enter dead-letter with inspectable attempt history. |
| Operations and safety | Replay records a complete operator audit; tenant isolation and secret/payload redaction tests pass for GraphQL, jobs, logs, traces, and errors. |
| Real integration | Receive and verify at least one actual development-store signed webhook. Record redacted evidence and configuration steps. This gate requires an available store and credentials; fixtures alone cannot complete it. |
| Architecture | Packwerk reports zero boundary violations; critical integration tests use MySQL, not SQLite. |
| Coverage and stability | Core idempotency, state-transition, and recovery branch coverage is at least 90%; overall branch coverage is at least 80%. The duplicate/crash/out-of-order suite passes 20 consecutive runs without a flaky failure. |
| Developer experience | A fresh clone reaches its first offline demo within 10 minutes in a documented reference environment. |
| Security | Dependency and security scans report no known high or critical findings at the release gate. |
| Release | Runnable setup/test/demo/benchmark entry points; threat model, at least two ADRs, failure matrix, contributor files, and a 90–120 second English demo; reviewed `v0.1.0` tag and release with actual results. |

### Performance targets, not current measurements

Document a fixed reference environment, such as 4 vCPU and 8 GB RAM with Docker, along with runtime versions, commands, workload, and raw output. The initial targets are 100 requests per second for 60 seconds, zero HTTP errors, webhook acceptance p95 below 250 ms, and normal-load processing completion p95 below 5 seconds. Expose job lag, retry count, dead-letter count, and processing latency as queryable metrics.

These are experimental targets, not a production SLA. A target miss must appear in the published results with bottleneck analysis; reporting a miss honestly is required, and replacing it with a fabricated success is unacceptable.

## Delivery discipline

Start with the smallest complete order-create path: signed fixture → durable receipt → job → projection/effect → query. Demonstrate ten duplicate deliveries leaving one canonical event and one effect before adding another event topic or broadening infrastructure.

Keep work in small issues, normally estimated at half a day to two days, with no more than two implementation issues in progress. Every pull request should explain the scenario, acceptance criteria, verification, and limitations. Calendar estimates are planning guidance, not a commitment to declare incomplete work done.

See the [roadmap](roadmap.md), [architecture](architecture.md), and [long-term goal](long-term-goal.md).
