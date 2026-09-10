# Package contracts

These contracts define the in-process order-create boundary. Composition tests use explicit test doubles; separate [fixture and normalization tests](fixtures.md) exercise the real source adapter and publisher. Authentication, persistence, and effect implementations remain pending. Interface tests do not establish HMAC ingress security, durable receipt, effect idempotency, or recovery. No HTTP ingestion route or default successful adapter is installed by this increment.

## Dependency direction

The root application composes four packages through `app/public` interfaces. Webhooks and Orders depend on EventLedger's public value contracts. Operations depends on EventLedger and Orders for redacted query results. EventLedger does not depend on another business package. No package depends on the root application.

Rails registers each package's `app/public` and implementation roots for autoloading and eager loading. Packwerk's `public_path` only controls boundary visibility. Composition lives in a reloadable application service and builds fresh objects; a boot-only initializer must not retain reloadable classes or handler instances.

Package models must not inherit the root `ApplicationRecord`, which would introduce a package-to-root dependency and a cycle. When models are implemented, each owning package may define its own private abstract base inheriting framework `ActiveRecord::Base`, using the same primary database connection specification. Do not establish an independent connection for effects or wrap handler execution in another package's transaction.

## Receipt and execution values

| Contract | Meaning |
| --- | --- |
| `EventLedger::Envelope` | Normalized `shop_id`, `source`, `external_event_id`, `topic`, `subject_id`, source `occurred_at`, optional `source_version`, sanitized `payload`, and `payload_sha256`. No HTTP headers, credentials, claim state, or caller-selected database event ID. |
| `EventLedger::Receipt` | Canonical `event_id`, `shop_id`, and duplicate indicator. A real receipt implementation may return it only after the database commit. It does not promise enqueue or processing success. |
| `EventLedger::PersistedEvent` | A canonical event ID with its immutable envelope, server receipt time, and durably assigned handler name/version. The processing path constructs it from tenant-scoped database state. |
| `EventLedger::EffectResult` | Committed effect ID, original outcome (`applied` or `stale`), and duplicate indicator. An existing effect preserves its recorded outcome. |
| `EventLedger::EventSummary` | Event ID, tenant, and lifecycle status, without a payload or credential. |
| `Orders::OrderSummary` | Tenant, source, external order identity, and projected state, without customer data. |

Value constructors validate shape, copy/freeze nested values, and use redacted inspection and generic validation errors. Constructing a value is not proof of authentication, authorization, or persistence. Those guarantees belong to the adapters and database transactions that will use these contracts.

Event summaries allow only `pending`, `processing`, `retry_wait`, `processed`, and `dead_letter` status strings. The current order-create summary allows only `created`. These are contract vocabularies, not implemented lifecycle transitions; later topics must add any new projected states deliberately. Arbitrary diagnostics or adapter strings must not become operator-visible status/state values. Default JSON serialization is redacted; readers expose the permitted fields explicitly.

`payload_sha256` means SHA-256 of the exact authenticated request bytes. The source adapter computes it before discarding the raw body. A repeated canonical identity with a different digest must produce an explicit conflict rather than replace the stored event. This deliberately distinguishes byte-different deliveries; it does not claim semantic equality after JSON reserialization. The normalized payload's allowlist and source ordering rules are defined in the order-create adapter, not inferred from arbitrary JSON or receipt time.

## Ports and composition

- `Webhooks::Ingress` requires explicit authentication, normalization, receipt, and handler-selection collaborators. Authentication must succeed before normalization or receipt. Source configuration is server-owned input; request headers alone cannot authorize a shop. The HTTP adapter remains unwired until that trust boundary is implemented.
- Receipt persistence accepts the envelope and a server-selected handler identity. Canonical insert assigns that identity once. Duplicate receipt returns the existing event and retains its original handler identity even if the current deployment selects a different version.
- `EventLedger::HandlerRegistry` selects a configured handler by source/topic for initial receipt and resolves an exact name/version for processing. Missing or duplicate registrations fail explicitly. It is immutable and does not discover handlers, maintain a global mutable registry, or fall back to a newer version.
- `Orders::Handler#call(event:)` accepts a persisted event assigned to its exact identity. Its required effect executor implements the Orders transaction below. The contract layer supplies no in-memory effect store or default success.
- `Operations::Queries` binds a required shop ID and forwards it to every event/order reader. Readers return the corresponding immutable summary or `nil`, never an Active Record object or relation. Results must match the bound tenant and requested identity. Binding a tenant is not authorization: the later GraphQL boundary must supply an already-authorized tenant.

The concrete method signatures and test-only examples live in `test/contracts`. Cross-package method behavior is verified by those integration tests because Packwerk checks constant references, not calls through injected objects.

## Ownership and transaction sequence

Orders owns private `OrderProjection` and `ProcessedEffect` models. EventLedger owns canonical receipts, processing attempts, claims, and lifecycle acknowledgment. The planned worker sequence is:

```text
EventLedger claim transaction
  commit and release claim locks
Orders effect transaction on the primary MySQL connection
  inspect/claim unique (event_id, handler_name, handler_version)
  lock/update the tenant-scoped order projection
  write the effect's original outcome
  commit projection and effect together
EventLedger acknowledgment transaction
  compare the current claim token before changing lifecycle state
```

No encompassing EventLedger transaction may swallow the Orders commit. No effect marker may commit independently of its projection change. Database tests must prove both constraints when those models are introduced. A failure before the Orders commit rolls back both writes; a failure after that commit leaves the effect intact so a retry can return its result before acknowledging the current claim. A stale worker must not acknowledge or fail a newer claim.

The chosen handler name/version belongs to the canonical event, not to a replay request or mutable runtime default. Processing resolves that stored identity. If the deployed code cannot resolve it, processing fails explicitly rather than substituting a new version. A future migration to a new effect identity requires a separate reviewed domain change.

## Enforcement and current limits

Packwerk 3.3.1 supplies dependency checks; `packwerk-extensions` 0.3.0 supplies privacy enforcement. The extension's complete entrypoint loads its required Sorbet runtime. Both direct additions and the transitive dependency are resolved in `Gemfile.lock`. See the [Packwerk boundary types](https://github.com/Shopify/packwerk/blob/v3.3.1/USAGE.md#types-of-boundary-checks) and [extension entrypoint](https://github.com/rubyatscale/packwerk-extensions/blob/v0.3.0/lib/packwerk-extensions.rb).

Run:

```sh
bundle exec packwerk validate
bundle exec packwerk check
bundle exec ruby script/check_package_boundaries.rb
bin/rails zeitwerk:check
bin/test
```

The probe copies tracked application files into a disposable directory. It verifies permitted public access and deliberately rejects private access, an undeclared dependency, and a dependency cycle. It never alters manifests or creates invalid references in the real checkout.

Strict dependency/privacy enforcement prevents new recorded exceptions. Static analysis still cannot prove dynamic method contracts, tenant authorization, SQL transaction ownership, or all metaprogramming behavior. Those require the focused contract tests now and real MySQL/HTTP/failure tests in subsequent issues. Coverage here measures interface branches; core idempotency and recovery coverage remain pending.
