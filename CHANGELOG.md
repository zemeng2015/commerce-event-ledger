# Changelog

All notable changes will be recorded here. No application version has been released.

## Unreleased

### Added

- Synthetic exact-byte HMAC fixture publisher with a database-independent dry run and loopback HTTP tests.
- Strict order-create normalization with trusted source configuration, opaque event identity preservation, bounded unambiguous JSON, and a minimal payload allowlist.

- Product charter, long-term goal, staged roadmap, and architecture decision records.
- MIT license, contributor guidance, security policy, code of conduct, and contribution templates.
- Repository checks for required files, UTF-8 text, merge markers, and relative documentation links.
- Foundation CI and a GitHub Actions dependency update policy.
- Rails 8.1.3.1 API generated on Ruby 4.0.6 with a Bundler-resolved lockfile.
- MySQL 8.4.11 Docker development environment, repeatable setup and test entry points.
- Health/database smoke tests, subprocess database/environment isolation regressions, and a fixture grant boundary check.
- Application CI for native Rails/MySQL and Docker setup, lint/security checks and coverage artifacts; Bundler and Docker dependency update policies.
- Four package contracts with immutable redacted values, exact handler-version routing, tenant-scoped query results, and reloadable composition using explicit adapters.
- Strict Packwerk dependency/privacy enforcement, isolated negative boundary probes, and native/Docker branch measurement checks.

### Not implemented

- Business schema and adapters, webhook endpoint, processing jobs, GraphQL API, and reliability tests.
- Demo, benchmark, failure evidence, development-store verification, and release artifacts.
