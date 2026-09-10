# S1 package contract checkpoint

Date: 2026-09-04. Scope: issues [#5](https://github.com/zemeng2015/commerce-event-ledger/issues/5) and [#4](https://github.com/zemeng2015/commerce-event-ledger/issues/4). The interface and CI increment is verified; the signed order-create pipeline and full v0.1 goal remain incomplete.

## Verified source and results

[PR #14](https://github.com/zemeng2015/commerce-event-ledger/pull/14) introduces the package contracts and checks. [Application CI run 33929137518](https://github.com/zemeng2015/commerce-event-ledger/actions/runs/33929137518) verified implementation commit `9e8597caa338907e65d3d8245d4588752966e243` on Ruby 4.0.6, Rails 8.1.3.1, and MySQL 8.4.11. [Foundation CI](https://github.com/zemeng2015/commerce-event-ledger/actions/runs/33929137510) also passed. Documentation and the retained summaries were added after that implementation result; PR checks also cover the final merge candidate.

| Check | Observed result |
| --- | --- |
| Native Rails/MySQL suite | 87 tests, 1,545 assertions; zero failures, errors, or skips |
| Fresh Docker suite | Same 87 tests and 1,545 assertions; zero failures, errors, or skips |
| Coverage in both environments | 80/87 branches (91.95%); 309/316 lines (97.78%); all 15 application/package source files loaded |
| Rails autoloading | `bin/rails zeitwerk:check` passed |
| Packwerk | `validate` passed; `check` reported no offenses |
| Enforcement probes | Declared public access passed; private access, undeclared dependency, and dependency cycle were rejected |
| Lint | 39 Ruby files inspected, no offenses |
| Security | Brakeman: zero warnings; updated bundler-audit: no vulnerabilities found |
| Development environment | Fresh Docker build/startup, repeated setup, health endpoint, and exact fixture database grant checks passed |

Retained [native coverage summary](evidence/package-contracts/native-coverage.json) and [Docker coverage summary](evidence/package-contracts/docker-coverage.json) are byte-identical outputs from the CI artifacts, with repository-relative paths. The run's `rails-coverage` and `docker-coverage` artifacts also contain the raw SimpleCov result and HTML report; artifacts have a seven-day retention period. The committed summaries preserve the measurement after artifact expiry.

These are **interface measurements**, not core idempotency, state-transition, or recovery coverage. The release requirements of at least 90% core and 80% overall branch coverage are unchanged. No business persistence or crash experiment has passed by virtue of this increment.

## Accepted behavior and review

- Four strict dependency/privacy packages with explicit public roots and Rails autoload/eager-load configuration.
- Immutable receipt/event/effect values, a registry resolving exact handler identities, and composition that requires explicit adapters.
- Authentication-before-receipt ordering, frozen exact body/header snapshots, tenant/source/digest matching, and failure propagation without sensitive details.
- Tenant-scoped read calls with fixed summary types, finite status/state vocabulary, and matching tenant/request identity.
- Redacted inspection and default Rails JSON serialization for public contract objects.
- Documented ownership: Orders commits projection/effect together; EventLedger claims and acknowledges in separate transactions. The canonical event retains its initially assigned handler version across duplicates and replay.

Independent review found an exception path that could preserve a collaborator's sensitive AuthenticationError message and unrestricted summary status/state strings. Both were corrected with regression tests before acceptance; default JSON serialization was also hardened. The first CI run found a Minitest 6 nil-assertion incompatibility, corrected before the passing run. No failed result is treated as acceptance evidence.

The 51 interface tests use clearly labeled test-only collaborators. They do not ship an in-memory repository, authenticate a real webhook, persist an event, or apply an order effect. See the [contract details](package-contracts.md) and [development commands](development.md#package-and-coverage-checks).

## Next dependency

Implement [issue #6](https://github.com/zemeng2015/commerce-event-ledger/issues/6): a synthetic `orders/create` fixture, exact-byte signing publisher, and normalization into the accepted envelope. Then add the trusted tenant/HMAC HTTP boundary (#7), canonical MySQL receipt (#8), and transactional processing (#9). Do not add another event topic before the ten-delivery vertical slice works. The real development-store verification gate remains pending supplied access.
