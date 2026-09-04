# Security policy

## Current status

There is no supported application release yet. This repository is a development foundation and must not be used to handle production merchant data. Future release support will be recorded here when releases exist.

## Reporting a vulnerability

Use **Security -> Advisories -> Report a vulnerability** in this GitHub repository to submit a private report. Include a minimal synthetic reproduction, affected commit, expected boundary, and observed behavior. Do not attach live credentials or customer payloads.

Avoid public issues for exploitable vulnerabilities or sensitive data. If private reporting is unavailable, request a private reporting channel through a public issue containing no vulnerability details.

## Design boundaries

- Offline synthetic fixtures are the default integration path.
- Webhook bodies are authenticated before acceptance; invalid signatures must receive `401`.
- Secrets, authorization tokens, and sensitive payloads must be redacted from telemetry and errors.
- Every query and replay operation must enforce tenant access and operator authorization.
- Replay is a recorded operational action, with bounded processing and no automatic merchant mutation.
- MySQL is the source of truth; the queue is not the durability guarantee.

These controls are planned requirements until backed by implementation and tests. The threat model and its failure matrix are release prerequisites, not completed evidence today.

See the [project charter](docs/project-charter.md) for invariants and the [long-term goal](docs/long-term-goal.md) for release gates.
