# ADR-0001: Rails modular monolith with MySQL business truth

- Status: **Accepted as the architecture baseline; Rails/MySQL scaffold and package contracts implemented, business persistence pending**
- Date: 2026-09-04
- Scope: Commerce Event Ledger v0.1

## Context

Commerce webhooks can be duplicated, delayed, delivered out of order, or interrupted by process failure. The project needs explicit transactional boundaries and reproducible correctness evidence for a narrow order-event workflow. Splitting services would add failure boundaries before the local business invariants are proven.

## Decision

Use a Rails API modular monolith with MySQL as the sole business source of truth. Use Active Job with Solid Queue for asynchronous execution, GraphQL Ruby for operator queries/replay, Minitest for behavior and MySQL integration tests, and Packwerk for package boundaries.

Limit the business design to four packages: Webhooks authenticates and normalizes; EventLedger owns durable events and processing lifecycle; Orders applies order projections and records database effects; Operations exposes authorized inspection, audited replay, and reconciliation. Calls cross declared public interfaces. Application composition wires handlers without reaching into private package models.

Keep canonical events, attempts, effects, projections, and operator audits in the business database. In particular, projection mutation and effect identity must commit atomically in one MySQL transaction. Queue records are scheduling data; their database placement must not be treated as evidence that receipt and enqueue are atomic.

The scaffold commits Ruby 4.0.6, Rails 8.1.3.1 and the Bundler-resolved lockfile and runs against MySQL 8.4.11. The [four-package configuration and public interfaces](../package-contracts.md) are implemented with strict boundary checks and explicit adapter contracts. Production queue persistence and business adapter behavior must still be implemented and verified.

## Alternatives considered

- Microservices or an event-stream platform would make deployment and distributed recovery substantially broader than the initial use case. No Kafka, Redis, Kubernetes, or network service boundaries are required for v0.1.
- SQLite-only tests would not establish the intended MySQL locking, uniqueness, and transaction behavior. Critical integration tests must run with MySQL.
- A synchronous webhook handler would tie source acknowledgment to domain execution and would not exercise the required asynchronous failure model.
- Extracting a reusable gem now would require an abstraction without demonstrated consumers. Revisit after concrete reuse emerges.

## Consequences

The codebase can preserve local transaction guarantees while separately testing the queue's at-least-once behavior. Package checks and public interfaces must prevent the monolith from becoming unconstrained cross-model access.

MySQL availability, worker scheduling, queue lag, and recovery timing remain operational concerns. This baseline does not establish production capacity, disaster recovery, external exactly-once effects, or safe merchant mutations.

## Validation plan

S1 must run the signed order-create path through the real Rails/MySQL application with ten duplicate deliveries and one effect. CI must report zero Packwerk violations. The current [development environment](../development.md) supports boot and MySQL smoke tests; those do not prove the domain invariants. Later failure experiments must verify the stronger [charter gates](../project-charter.md#completion-criteria).

See [architecture](../architecture.md) and [ADR-0002](0002-acceptance-and-recovery.md).
