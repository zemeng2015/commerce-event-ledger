# Long-term goal

Status: **active — S0 complete; S1 signed HTTP and canonical MySQL receipt accepted; processing/effects pending**. These increments do not complete this goal. Business processing, integration, failure recovery, and release work remain outstanding. See the [receipt acceptance](s1-receipt-checkpoint.md), earlier [fixture acceptance](s1-fixture-checkpoint.md), and [development setup](development.md).

## Objective

Develop and release Commerce Event Ledger `v0.1.0`: an independent, English-first, MIT-licensed Rails API modular monolith that uses MySQL as its sole business source of truth to accept signed commerce webhooks, enforce canonical-event and database-effect idempotency, process at least once, recover from worker and enqueue failures, and support tenant-scoped, audited operations. Prove its stated guarantees with reproducible MySQL-backed correctness tests, failure experiments, real development-store integration, and honest performance results.

The required stack is Rails API, MySQL, Active Job/Solid Queue, GraphQL Ruby, Packwerk, and Minitest. The four business packages are Webhooks, EventLedger, Orders, and Operations. Ruby 4.0.6, Rails 8.1.3.1, MySQL 8.4.11 and the resolved gem lockfile are committed. See the [charter](project-charter.md) for invariants and [architecture](architecture.md) for the design.

## Definition of done

The goal is complete only when all required implementation and evidence exist and are reviewable:

- [ ] A documented fresh clone reaches its first signed offline fixture demo within 10 minutes in the stated reference environment.
- [ ] Create, update, and cancellation events have tested normalization and order-transition policies; stale source events cannot regress projections.
- [ ] Invalid HMAC requests always return `401` in the test matrix without creating accepted events or work.
- [ ] One hundred sequential and one hundred concurrent duplicate deliveries each leave one canonical event and one database domain effect.
- [ ] A worker crash after the effect transaction commits and before queue acknowledgment recovers with one effect; the projection write and effect ledger share the same MySQL transaction.
- [ ] Receipt/enqueue gaps, process restarts, transient errors, exhausted retries, dead-letter states, and stale claims have reproducible recovery tests; acknowledged `202` events do not silently disappear.
- [ ] GraphQL provides tenant-scoped event/order/attempt inspection and authorized replay with operator, reason, timestamp, and original-event audit. Replay preserves idempotency; tenant isolation and sensitive-data redaction tests pass.
- [ ] At least one actual Shopify development-store signed webhook has been received and verified, with redacted evidence. An available development store and credentials are an external prerequisite for this gate; offline fixtures do not substitute for it.
- [ ] Structured logs, correlation IDs, traces, and queryable job-lag, retry, dead-letter, and processing-latency metrics are demonstrated without secrets or full sensitive payloads.
- [ ] MySQL-backed CI passes with zero Packwerk violations; core idempotency/state-transition/recovery branch coverage is at least 90%, overall branch coverage is at least 80%, and the duplicate/crash/out-of-order suite passes 20 consecutive runs without flakiness.
- [ ] Dependency/security scans show no known high or critical findings at release.
- [ ] A reproducible 100 RPS / 60-second workload records the environment, exact command, raw results, and bottleneck analysis. Targets are zero HTTP errors, acceptance p95 below 250 ms, and normal-load completion p95 below 5 seconds; actual results and misses must be reported honestly rather than treated as an SLA.
- [ ] Runnable setup/test/demo/benchmark entry points, architecture, threat model, at least two reviewed ADRs, failure matrix, contributor/security files, a 90–120 second English demo, and an evidence-backed `v0.1.0` tag/release are available.

## Milestones and current work

| Milestone | Completion gate | State |
| --- | --- | --- |
| S0 | Establish repository and durable project foundation | Complete — public repository, reviewed docs, passing Foundation CI, ten work items |
| S1 / `v0.0.1` | Signed order-create vertical slice: ten duplicates, one canonical event, one effect, MySQL-backed checks | In progress — signed HTTP receipt and canonical storage accepted; queue processing, order effects, and queries pending |
| S2 | Concurrency, transactional effect correctness, retry, dead-letter, crash and enqueue-gap recovery, ordering | Pending |
| S3 | Real integration, GraphQL replay/audit, tenant/redaction verification, observability and experiments | Pending |
| S4 / `v0.1.0` | All required evidence, release-quality documentation and demo, honest release | Pending |

Next action: implement [issue #9: asynchronous processing and transactional order effects](https://github.com/zemeng2015/commerce-event-ledger/issues/9). HTTP authentication (#7) and canonical receipt (#8) are accepted; the [receipt checkpoint](s1-receipt-checkpoint.md) records 117 passing tests in each environment, 20 receipt race repetitions, and the remaining limits. Continue only `orders/create` through asynchronous projection/effect processing and tenant-scoped status queries. Do not add another topic until ten duplicate deliveries demonstrably produce one event and one effect.

## Execution rules

Use the [roadmap](roadmap.md) as the ordered work queue. Keep at most two implementation issues in progress and attach acceptance evidence to each completed issue. At each meaningful checkpoint, update the milestone state, completed evidence, unresolved limitations, and concrete next action. A four-week plan is an estimate, not permission to skip completion gates.

This goal does not include other projects, storefronts, payments, AI features, Kafka, Redis, Kubernetes, merchant-side writes, or speculative service splitting. Preserve the seven charter invariants throughout changes. The one-effect claim applies to the local database transaction, not distributed systems.

Repository creation and development planning do not imply that scheduled automation exists or that a release has occurred. Integration credentials, production deployment, and external publication steps must be handled according to the user's active authorization and available environment. If development-store access is unavailable, continue independent implementation while recording the real-integration gate as pending.
