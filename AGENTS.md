# Commerce Event Ledger development instructions

## Scope and durable state

This repository is exclusively Commerce Event Ledger. Read `docs/project-charter.md`, `docs/long-term-goal.md`, `docs/roadmap.md`, relevant ADRs, and the current Git diff before work. Keep other projects and personal background outside this public repository.

Before writing, confirm that the checkout's `origin` is `https://github.com/zemeng2015/commerce-event-ledger.git` (or the equivalent SSH URL). Use this isolated checkout, not a shared planning directory used by another project.

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

Repository checks:

```sh
python3 script/check_repository.py
git diff --check
```

The Ruby 4.0.6 / Rails 8.1.3.1 / MySQL 8.4.11 scaffold and lockfile are implemented. Follow `docs/development.md` for the tested Docker setup. Run `docker compose up --build --wait` and `docker compose run --rm app ruby bin/test`, or use `ruby bin/setup` / `ruby bin/test` with an isolated native MySQL instance. Never bypass the scripts' database URL or environment protections to run against unrelated data.

Application CI checks actual MySQL access, `/up`, script isolation, Docker startup/repeated setup, exact fixture grants, `bin/rails zeitwerk:check`, `bin/rubocop`, `bin/brakeman --no-pager`, and `bin/bundler-audit check --update`. It also checks strict Packwerk dependencies/privacy, positive/negative boundary probes, public interface behavior, and actual source loading for branch coverage. Read `docs/package-contracts.md` before implementing adapters; the interface layer has no successful default storage or authentication implementation. Disclose dependency additions and architecture changes in the change summary.

Future gates include business MySQL tests, Packwerk, meaningful core/overall branch coverage, repeated failure scenarios, and a clean-clone signed-event demo. Scaffold coverage with zero commerce branches is not acceptance evidence for those gates. Report commands actually run and distinguish environment blockers from test failures. Do not invent passing results, releases, benchmark values, or production scale.

Use English for public documentation and issues. Optional Chinese explanations belong in `docs/zh-CN/`. Keep docs consistent with the implemented state.
