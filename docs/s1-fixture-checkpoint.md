# S1 signed fixture checkpoint

Date: 2026-09-10. [PR #15](https://github.com/zemeng2015/commerce-event-ledger/pull/15) is merged as `5d85b7dc0be2170189a15e4d6c02ab34f8c83ea7`, completing [issue #6](https://github.com/zemeng2015/commerce-event-ledger/issues/6). The merge tree matches verified implementation commit `a001abc0301533f472fba2c87f8492658f7fa630`.

## Verified evidence

[Application CI run 34485232807](https://github.com/zemeng2015/commerce-event-ledger/actions/runs/34485232807) and [Foundation CI](https://github.com/zemeng2015/commerce-event-ledger/actions/runs/34485232760) passed on the verified head.

| Check | Observed result |
| --- | --- |
| Native MySQL tests | 102 tests, 1,832 assertions; zero failures, errors, or skips |
| Fresh Docker tests | Same 102 tests and 1,832 assertions; no failures, errors, or skips |
| Source coverage in both environments | 121/129 branches (93.8%); 447/454 lines (98.46%); all 19 application/package/library files loaded |
| Standalone publisher | Dry-run succeeded without installing the application bundle or starting MySQL, despite an unusable inherited database URL and production environment |
| Package checks | Packwerk validate/check passed; public access succeeded and private/dependency/cycle probes were rejected |
| Other checks | Zeitwerk passed; 45 Ruby files linted without offenses; Brakeman zero warnings; updated bundler-audit found no vulnerabilities |

These coverage numbers describe the current source, including normalization and the publisher. They do not establish the pending core idempotency/state-transition/recovery coverage gate. CI retains native and Docker coverage artifacts for seven days; the tests and source commit make the measurement reproducible.

A separate Windows test used a Python HTTP receiver and Python's `hmac` implementation to verify three actual Ruby publisher requests. All three carried the same 156-byte body and correct HMAC, one event ID, and three different delivery IDs. Publishing succeeded with both proxy environment variables pointed at an unusable loopback proxy. The tested fixture SHA-256 is `303b6b84d410c13eac47d70ae37dba6238c2d15f718956dbfece35e77e3532fb`.

## Accepted scope

- Deterministic synthetic UTF-8 fixture and exact-byte HMAC publisher, with a database-independent dry run, bounded local transport, and redacted diagnostics.
- Immutable trusted source configuration and strict order-create normalization; duplicate JSON keys, malformed source metadata, invalid timestamps, and excessive body size are rejected.
- Opaque source event identifiers are preserved and qualified by topic. Delivery identifiers do not become canonical identities.
- Only order identity, `created` state, and source timestamps enter the normalized payload; other fields are discarded.
- No new dependencies beyond the existing runtime and its standard libraries.

See [fixture commands and detailed limits](fixtures.md). Dry-run validates invocation/metadata and signs bytes; it does not independently certify body schema or persistence. The normalization tests validate the committed fixture's schema.

## Remaining work

Next is [issue #7](https://github.com/zemeng2015/commerce-event-ledger/issues/7): implement the HTTP HMAC verifier and trusted tenant routing, with invalid-HMAC `401` and redaction tests. HMAC covers the body, not arbitrary request headers; tenant authorization must not be inferred solely from a shop-domain header. Then add canonical MySQL receipt (#8), processing/effect transactions (#9), and status queries (#10).

No HTTP receiver, durable receipt, effect, restart recovery, ten-delivery database demonstration, or real development-store verification is established by this checkpoint. S1 and the full v0.1 goal remain active.
