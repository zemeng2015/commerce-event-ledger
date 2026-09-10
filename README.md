# Commerce Event Ledger

Failure-aware webhook ingestion for Rails commerce applications.

Commerce webhooks can arrive twice, late, or out of order. Workers can crash after changing an order but before acknowledging a job. This project is being built to make accepted events recoverable, database effects idempotent, and failures explainable.

**Status: scaffold, package contracts, and signed fixture tooling; S1 in progress.** The API boots, exposes `/up`, and has a reproducible Docker environment. A standalone publisher signs exact fixture bytes, and a strict adapter normalizes order-create data. HTTP webhook ingestion, order persistence/processing, GraphQL operations, and reliability guarantees are not implemented yet. The first milestone remains ten signed deliveries producing one canonical event and one order effect. See the [roadmap](docs/roadmap.md) and [active development goal](docs/long-term-goal.md).

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

The scaffold uses Ruby 4.0.6, Rails 8.1.3.1, and MySQL 8.4.11. Bundler resolves the committed dependency lockfile; GraphQL Ruby, Solid Queue, Packwerk, and SimpleCov are included for the pipeline and its checks. The [four-package contracts](docs/package-contracts.md) define receipt, exact-version handler dispatch, and tenant-scoped query ports. Authentication, database adapters, queue persistence, and the GraphQL schema remain upcoming work. See [architecture](docs/architecture.md) for boundaries and transaction decisions.

## Run the scaffold

With Git and Docker Compose v2 using Linux containers:

```sh
git clone https://github.com/zemeng2015/commerce-event-ledger.git
cd commerce-event-ledger
docker compose up --build --wait
docker compose run --rm app ruby bin/test
```

The health endpoint is available at `http://127.0.0.1:3000/up`. No host Ruby or MySQL installation is needed for this path. The database is private to the Compose network and uses a dedicated disposable fixture account. See [development setup](docs/development.md) for native Ruby, repeatable setup, and troubleshooting.

`bin/setup` prepares fixed development/test databases without resetting existing data. `bin/test` forces the test environment and rejects database URL and environment overrides. These commands do not demonstrate durable event receipt or one-effect processing. `bin/demo` and `bin/benchmark` remain planned.

With Ruby 4.0.6, `ruby bin/publish_fixture --dry-run` signs the synthetic fixture without Rails, MySQL, or network access. See the [fixture commands and normalization contract](docs/fixtures.md). Actual local publishing requires the HTTP receiver, which is not implemented yet.

## Repository checks

With Python 3.11+:

```sh
python3 script/check_repository.py
git diff --check
```

On Windows, use `python` instead of `python3`. This validates repository files and relative documentation links. It does not run Rails or verify webhook behavior. The Foundation CI workflow runs the same checks on Linux.

Application CI separately runs MySQL smoke tests, interface composition and redaction tests, script-isolation regressions, Rails autoload checks, strict Packwerk boundaries with negative probes, lint, dependency/security scans, and a fresh Docker build/startup/repeated-setup path. It checks that all application/package sources are loaded for branch measurement. Interface coverage does not satisfy the release's core idempotency/recovery coverage gate.

## Development and evidence

- [Project charter and invariants](docs/project-charter.md)
- [Milestones and acceptance gates](docs/roadmap.md)
- [Long-term goal and current state](docs/long-term-goal.md)
- [Architecture](docs/architecture.md)
- [Verified scaffold checkpoint](docs/s1-scaffold-checkpoint.md)
- [Verified package contract checkpoint](docs/s1-package-checkpoint.md)
- [Verified signed fixture checkpoint](docs/s1-fixture-checkpoint.md)
- [ADR 0001: modular monolith](docs/adr/0001-modular-monolith.md)
- [ADR 0002: durable acceptance and recovery](docs/adr/0002-acceptance-and-recovery.md)
- [Contributing](CONTRIBUTING.md), [security](SECURITY.md), and [changelog](CHANGELOG.md)

The initial backlog is tracked in [GitHub issues](https://github.com/zemeng2015/commerce-event-ledger/issues). Correctness tests, coverage, performance data, and clean-clone timings will be published with their raw commands and limitations. No production-readiness or performance result is claimed today.

## Non-goals

No storefront, cart, payments, inventory automation, dashboard, LLM features, Kafka, Redis, Kubernetes, or microservice split. No mutation of real merchant orders. No gem extraction until reuse is demonstrated.

## License and affiliation

[MIT](LICENSE). This is an independent project, not affiliated with or endorsed by Shopify.
