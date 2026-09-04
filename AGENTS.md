# Commerce Event Ledger development instructions

## Scope and durable state

This repository is exclusively Commerce Event Ledger. Read `docs/project-charter.md`, `docs/long-term-goal.md`, `docs/roadmap.md`, relevant ADRs, and the current Git diff before work. Keep other projects and personal background outside this public repository.

The active goal is the complete v0.1 acceptance definition. Completing a task or sprint is a checkpoint, not completion of the goal. Update durable state with actual evidence, unresolved gates, and the next dependency after each accepted increment.

## Delivery

- Keep WIP at two implementation tasks or fewer, with explicit file ownership and dependencies.
- Use `codex/` for development branches. The initial foundation is on `main`.
- Use small, reviewable increments with scenario, acceptance criteria, and verification commands.
- Give independent agents bounded contracts; do not overlap file ownership. Integrate and review the actual changes.
- Implement the order-create vertical slice before additional topics or conveniences.
- Preserve user changes; never use destructive Git cleanup to resolve conflicts.

## Architecture and correctness

- Rails API modular monolith, MySQL as the only business source of truth.
- Four packages: Webhooks, EventLedger, Orders, Operations. Interact through explicit public interfaces.
- Active Job with Solid Queue. Do not build a queue or add Redis/Kafka to work around correctness defects.
- Use database unique constraints for canonical events and handler effects, with tenant-safe keys and queries.
- Projection updates and effect records must share a transaction. State recovery must handle failures at commit/enqueue and effect/ack boundaries.
- Promise at-least-once processing. Do not assert distributed exactly-once behavior.
- Test race conditions and recovery on MySQL; SQLite is not a substitute for the acceptance suite.
- Keep stale-event ordering and equal-version behavior explicit and tested.

## Safety and public artifacts

- Default to synthetic offline fixtures. Never commit credentials, real webhook bodies, customer data, environment files, or the original personal planning materials.
- HMAC validation uses the exact request bytes and constant-time comparison. Secrets and payloads must be absent from logs, traces, and errors.
- Tenant identity and operator authorization must be trusted server-side inputs; a GraphQL argument alone is not authorization.
- Replay requires operator identity, reason, timestamp, and original event association.
- Do not change production orders, inventory, payments, or infrastructure. A live development-store test needs separately supplied access and scope.
- Do not contact third parties, deploy, or publish a release without applicable user authorization. Never treat a roadmap item as permission by itself.

## Verification and documentation

Current foundation checks:

```sh
python3 script/check_repository.py
git diff --check
```

Application commands are not implemented yet. When scaffolding, record exact Ruby/Rails/MySQL versions, add the lockfile and dependency update policy, and implement the documented runtime checks. Disclose dependency additions and architecture changes in the change summary.

Future gates include MySQL tests, lint, security/dependency scans, Packwerk, branch coverage, repeated failure scenarios, and a clean-clone demo. Report commands actually run and distinguish environment blockers from test failures. Do not invent passing results, releases, benchmark values, or production scale.

Use English for public documentation and issues. Optional Chinese explanations belong in `docs/zh-CN/`. Keep docs consistent with the implemented state.
