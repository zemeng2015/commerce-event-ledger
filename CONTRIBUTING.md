# Contributing

The repository is establishing its foundation. The first runnable increment covers one signed order-create fixture, canonical event deduplication, background processing, and one order effect. Read the [roadmap](docs/roadmap.md) before adding features.

## Working on a change

1. Read the [charter](docs/project-charter.md), [architecture](docs/architecture.md), and [repository instructions](AGENTS.md).
2. Select a scoped issue and describe the failure or user scenario it addresses.
3. Create a focused branch. Use `codex/` when working with Codex.
4. Add implementation and proportionate regression coverage. Use synthetic data only.
5. Run the available checks and record exact commands and results.
6. Open a PR describing the problem, decision, tests, and remaining limitations.

Current verification is:

```sh
python3 script/check_repository.py
git diff --check
```

On Windows, `python` can replace `python3`. Ruby/MySQL integration checks will be introduced with the application scaffold. A successful foundation check says nothing about application correctness.

## Review expectations

- Changes stay within the issue's acceptance criteria and explicit package interfaces.
- Database invariants are enforced in MySQL, not only through application validation.
- Crash, concurrency, tenant isolation, and redaction behavior receive tests where affected.
- New dependencies and architecture changes are explained.
- Documentation and recorded project state describe what actually works.
- Evidence is reproducible; benchmark targets are never presented as measured results.

Follow the [Code of Conduct](CODE_OF_CONDUCT.md). Report sensitive findings through the [security process](SECURITY.md). Contributions are accepted under the [MIT license](LICENSE).
