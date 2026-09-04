# S1 scaffold acceptance — 2026-09-04

The runtime foundation in [issue #2](https://github.com/zemeng2015/commerce-event-ledger/issues/2) is accepted and [PR #12](https://github.com/zemeng2015/commerce-event-ledger/pull/12) is merged. S1's signed-event vertical slice and the complete v0.1 goal remain in progress.

## Implemented and verified

- Ruby 4.0.6 and Rails 8.1.3.1, with a real Bundler 4.0.16 resolution and committed gem checksums. [Upstream scaffold generation](https://github.com/zemeng2015/commerce-event-ledger/actions/runs/33927013000) verified boot against MySQL 8.4.11. Generated credentials were excluded from integration.
- A Docker-only developer path: `docker compose up --build --wait`. MySQL stays inside the Compose network; Rails is published only at `127.0.0.1:3000`.
- `bin/setup` repeatedly prepares fixed development/test databases without resetting data. `bin/test` enforces the test environment. Both reject `DATABASE_URL` and `PRIMARY_DATABASE_URL`; test execution also rejects environment-switching arguments.
- Dedicated disposable fixture credentials with literal database grants. A CI probe verifies valid test-database access and MySQL `1044` denial for a wildcard-similar unrelated database.
- Two HTTP/database smoke tests and 34 subprocess environment-guard regressions. Both native and Docker runs passed **36 tests and 192 assertions**, with zero failures, errors or skips.
- Rails autoload checks and RuboCop passed; Brakeman reported zero warnings, and the updated dependency audit found no vulnerabilities.
- Separate Foundation CI verifies repository text/link hygiene. Bundler, Docker and Actions update policies are present.

The final reviewed code was `c44403ac346fa478510aa55971f8f0f452a231bb`, verified by [Application CI](https://github.com/zemeng2015/commerce-event-ledger/actions/runs/33927917837) and [Foundation CI](https://github.com/zemeng2015/commerce-event-ledger/actions/runs/33927917552). It merged as `e0b6900ef5e0ff18049791eea6512525d6745a03`; the merge tree was compared to the verified PR head and contained no content changes.

Independent review accepted scope, architecture, environment/database isolation, executable entry points, tests and documentation after rework. The integration owner verified the actual logs and GitHub state. All runtime checks used Ubuntu GitHub Actions and disposable MySQL containers. No Ruby, Docker, WSL distribution or new database service was installed on the bootstrap Windows host.

## Evidence limits

This application currently boots; it does not yet accept signed webhooks or produce order effects. The four packages, business tables, queue persistence, worker/recovery lifecycle, GraphQL schema, telemetry pipeline and failure/load harness remain unimplemented.

Coverage artifacts are available, but the scaffold has no commerce branches. The reported `0/0` branch denominator is not evidence for the 90% core or 80% overall branch targets; early boot and package coverage must be verified when real domain code is introduced. A passing startup health check does not establish event durability, tenant isolation, replay correctness or crash recovery.

The Docker job exercised a fresh build, healthy startup, repeated setup, tests and grant boundaries. It does not establish the ten-minute clone-to-signed-demo requirement because that demo does not exist yet. No production deployment, release tag, benchmark result, development-store receipt or demo recording is claimed.

## Next dependency

Implement [issue #5](https://github.com/zemeng2015/commerce-event-ledger/issues/5): four business package interfaces and meaningful strict boundary checks. Packwerk 3.3.1 core enforces dependencies only; privacy enforcement requires a separately evaluated extension. A public/private negative probe and `packwerk validate` are required before claiming that package boundaries work.

Then finish the remaining boundary/coverage work in [issue #4](https://github.com/zemeng2015/commerce-event-ledger/issues/4), followed by the signed order-create path in [the roadmap](roadmap.md). Keep WIP at two implementation tasks or fewer and retain the full [long-term completion criteria](long-term-goal.md).
