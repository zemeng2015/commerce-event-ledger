# Foundation checkpoint — 2026-09-04

S0 is complete. S1 has not started, and the full v0.1 goal remains active.

## Repository and accepted evidence

- Public repository: [zemeng2015/commerce-event-ledger](https://github.com/zemeng2015/commerce-event-ledger), default branch `main`, MIT license.
- Initial foundation commit: [`1f827ae`](https://github.com/zemeng2015/commerce-event-ledger/commit/1f827aeda394876011bd9b7ff3a15582d171e371).
- [Foundation CI passed](https://github.com/zemeng2015/commerce-event-ledger/actions/runs/33926569211) for that commit.
- Local verification: `python script/check_repository.py` passed for 23 tracked files and 41 relative file links; `git diff --cached --check` passed before commit.
- An independent read-only review accepted scope, architecture, safety, documentation checks, and foundation integration. Minor template/name cleanup was incorporated before commit.
- Private vulnerability reporting is enabled; repository visibility and `origin` were verified. GitHub Actions updates are configured through Dependabot.
- The initial scope is the order-create vertical slice. No application code or runtime test results exist yet.

## Initial issue backlog

| Issue | Outcome | State at this checkpoint |
| --- | --- | --- |
| [#1](https://github.com/zemeng2015/commerce-event-ledger/issues/1) | Repository, charter and contributor foundation | Complete |
| [#2](https://github.com/zemeng2015/commerce-event-ledger/issues/2) | Rails API, MySQL Compose and reproducible setup | Next |
| [#4](https://github.com/zemeng2015/commerce-event-ledger/issues/4) | MySQL tests, lint, security, coverage and boundary CI | Pending |
| [#5](https://github.com/zemeng2015/commerce-event-ledger/issues/5) | Four packages and public handler contracts | Pending |
| [#6](https://github.com/zemeng2015/commerce-event-ledger/issues/6) | Normalized order-create envelope and signed fixture | Pending |
| [#7](https://github.com/zemeng2015/commerce-event-ledger/issues/7) | HMAC verification and tenant-safe ingress | Pending |
| [#8](https://github.com/zemeng2015/commerce-event-ledger/issues/8) | MySQL canonical-event uniqueness | Pending |
| [#9](https://github.com/zemeng2015/commerce-event-ledger/issues/9) | Asynchronous order projection and transactional effect | Pending |
| [#10](https://github.com/zemeng2015/commerce-event-ledger/issues/10) | Tenant-scoped GraphQL status | Pending |
| [#11](https://github.com/zemeng2015/commerce-event-ledger/issues/11) | Ten-delivery offline demo and v0.0.1 evidence | Pending |

The [v0.0.1 milestone](https://github.com/zemeng2015/commerce-event-ledger/milestone/1) owns this first slice. The [v0.1.0 milestone](https://github.com/zemeng2015/commerce-event-ledger/milestone/2) retains the complete release scope described in the [long-term goal](long-term-goal.md). GitHub shares issue and PR numbering; #3 is an automatically generated dependency-update PR, not a missing work item. Each work item contains a scenario, dependencies, acceptance criteria and proposed verification commands.

## Preflight and unresolved prerequisites

On 2026-09-04, an exact-name GitHub public search returned no repository matches before creation; RubyGems returned no gem for `commerce-event-ledger` or `commerce_event_ledger`. Basic exact-name web search found no obvious conflict. This was a discoverability check; no trademark-register search or name reservation was performed. Gem publication is outside the initial scope.

The [Ruby download page](https://www.ruby-lang.org/en/downloads/) and [Rails security release announcement](https://rubyonrails.org/2026/7/29/Rails-Versions-7-2-3-2-8-0-5-1-and-8-1-3-1-have-been-released) identify Ruby 4.0.6 and Rails 8.1.3.1 as current scaffold candidates on this date. Full mysql2/Solid Queue/Packwerk/GraphQL/telemetry bundle compatibility has not been tested. Issue #2 must verify compatibility and commit runtime files and the lockfile; these candidate versions are not an implemented baseline.

The bootstrap host has no Ruby or Docker executable available and no configured WSL distribution was listed. S1 needs a working Linux/container or equivalent Ruby/MySQL environment. No host installation was performed during foundation setup.

Development-store access and credentials have not been supplied. Real webhook receipt remains a required v0.1 evidence gate. No benchmark, coverage result, failure proof, release tag, demo recording, production deployment, or scheduled automation is claimed by this checkpoint.
