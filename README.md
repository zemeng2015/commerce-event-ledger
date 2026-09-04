# Commerce Event Ledger

Failure-aware webhook ingestion for Rails commerce applications.

Commerce webhooks can arrive twice, late, or out of order. Workers can crash after changing an order but before acknowledging a job. This project is being built to make accepted events recoverable, database effects idempotent, and failures explainable.

**Status: repository foundation.** Application code, runtime setup, benchmarks, and releases are not implemented yet. The first milestone is one signed `orders/create` fixture delivered ten times, producing one canonical event and one order effect. See the [roadmap](docs/roadmap.md) and [active development goal](docs/long-term-goal.md).

## Intended guarantees

- An authenticated event acknowledged with `202 Accepted` is durably recorded and recoverable after restart.
- MySQL enforces one canonical event per tenant, source, and external event ID.
- A handler version applies one database effect per event, even after a worker crash.
- Older events cannot move an order projection backwards.
- Operators can inspect processing attempts and request replay with an audit trail.
- Tenant boundaries and sensitive-data redaction are tested explicitly.

These are acceptance criteria, not claims about a shipped implementation. Processing is **at least once**. This project does not promise distributed exactly-once execution or idempotent external side effects.

## Planned architecture

```text
Signed fixture / optional Shopify development store
    -> Webhooks: HMAC verification and normalization
    -> EventLedger: durable MySQL inbox and deduplication
    -> Active Job / Solid Queue
    -> Orders: transactional projection and effect ledger
    -> Operations: GraphQL status, recovery, and audited replay
```

Rails API, MySQL, GraphQL Ruby, Solid Queue, Packwerk, Minitest, and Docker Compose form the planned baseline. See [architecture](docs/architecture.md) for boundaries and transaction decisions. Runtime versions and the dependency lockfile will be committed with the executable Rails scaffold.

## Check this foundation

Only Git and Python 3.11+ are needed for the current repository check:

```sh
git clone https://github.com/zemeng2015/commerce-event-ledger.git
cd commerce-event-ledger
python3 script/check_repository.py
git diff --check
```

On Windows, use `python` instead of `python3`. This validates repository files and relative documentation links. It does not run Rails or verify webhook behavior. The Foundation CI workflow runs the same checks on Linux.

The future application will provide `bin/setup`, `bin/test`, `bin/demo`, and `bin/benchmark`. They will be documented as runnable only when implemented and verified. Offline fixtures will be the default; a live store will not be needed for the local demo.

## Development and evidence

- [Project charter and invariants](docs/project-charter.md)
- [Milestones and acceptance gates](docs/roadmap.md)
- [Long-term goal and current state](docs/long-term-goal.md)
- [Architecture](docs/architecture.md)
- [ADR 0001: modular monolith](docs/adr/0001-modular-monolith.md)
- [ADR 0002: durable acceptance and recovery](docs/adr/0002-acceptance-and-recovery.md)
- [Contributing](CONTRIBUTING.md), [security](SECURITY.md), and [changelog](CHANGELOG.md)

The initial backlog is tracked in [GitHub issues](https://github.com/zemeng2015/commerce-event-ledger/issues). Correctness tests, coverage, performance data, and clean-clone timings will be published with their raw commands and limitations. No production-readiness or performance result is claimed today.

## Non-goals

No storefront, cart, payments, inventory automation, dashboard, LLM features, Kafka, Redis, Kubernetes, or microservice split. No mutation of real merchant orders. No gem extraction until reuse is demonstrated.

## License and affiliation

[MIT](LICENSE). This is an independent project, not affiliated with or endorsed by Shopify.
