# ADR-0002: Durable acceptance, transactional effects, and stale-work recovery

- Status: **Proposed — implementation and failure evidence pending**
- Date: 2026-09-04
- Scope: Receipt acknowledgment, processing idempotency, and recovery

## Context

A durable event can commit before its queue job is created. A worker can commit a domain effect and crash before queue acknowledgment. Retried jobs and expired claims can run concurrently. A successful HTTP acknowledgment must therefore rely on durable business state, while repeated processing must be safe in the business database.

The initial release is deliberately small. Before adding a custom transactional outbox, test whether canonical-event persistence plus recovery can satisfy its stated acceptance and recovery requirements.

## Proposed decision

### Receipt transaction and enqueue gap

Authenticate the exact raw body before accepting an event. Insert or find a canonical event under `UNIQUE(shop_id, source, external_event_id)`, preserving the original canonical payload and updating only safe delivery metadata on duplicates. Commit this receipt transaction before returning `202`.

Enqueue via Active Job after receipt commit. Enqueue failure does not erase durable acceptance: a recovery scan must find eligible canonical events even when no job was ever created. If the database transaction fails, no `202` may be returned. Do not assume the job adapter shares the receipt transaction, even if queue and business tables happen to use the same MySQL server.

### Effect transaction

Orders owns the private projection and effect models and one MySQL business-database transaction for checking/claiming the handler effect key, applying the order transition, and writing the effect result. Enforce `UNIQUE(event_id, handler_name, handler_version)` in the database. Serialize updates to the same order projection and keep lock ordering consistent. EventLedger commits the claim before invoking Orders, then acknowledges the outcome in a separate claim-token-guarded transaction; no encompassing EventLedger transaction may absorb the Orders commit. The [public contracts](../package-contracts.md) establish this ownership; actual MySQL behavior and crash recovery still require implementation evidence.

An implementation may insert an effect marker before the projection mutation only if the marker and mutation remain uncommitted within that same transaction. A durable success marker must never precede the domain write in a separate transaction. Unique-key conflicts and deadlocks must cause rollback/re-read or bounded retry of the entire relevant unit.

If the transaction rolls back, no effect was committed and a retry may apply it. If it commits and the worker dies before job acknowledgment, a retry observes the existing effect and does not reapply the transition. A stale event records a terminal no-op outcome without regressing the projection. No external side effect is part of this transaction or guarantee.

### Claims, retries, and recovery

Persist bounded processing claims, attempt history, eligibility times, and sanitized failure outcomes. Use bounded exponential backoff for transient errors and an explicit dead-letter outcome after exhaustion. Recovery repeatedly finds pending/retry events whose eligibility time has arrived and processing events whose claims expired, and requests jobs through Active Job.

Duplicate recovery enqueue requests are permitted. Claim tokens or equivalent compare-and-set guards must prevent an expired worker from overwriting a newer attempt's lifecycle state. Database locks and effect uniqueness must still protect domain writes if execution overlaps. Dead-letter events stay terminal until an authorized replay records why processing should be attempted again.

Recovery must run on a documented schedule and after service restart. A durable eligible event cannot depend solely on an in-memory callback or queue job for discoverability. Recovery scans need bounded batches, suitable indexes, and observable lag/failure metrics.

### Replay

An operator must be authenticated and authorized for the event's tenant and must provide a reason. Replay records operator, tenant, reason, timestamp, and original event association. Audit recording and the durable replay request need a coherent transaction boundary so a recoverable replay cannot lack its audit.

Replay preserves canonical event identity and handler-version effect identity. It cannot delete the effect record or manufacture a new handler version to force a repeated effect. Attempts remain inspectable; already-processed effects can produce an audited no-op. Handler-version changes require a separate reviewed migration policy.

Canonical receipt assigns the server-selected handler name/version once and persists it. Duplicate receipt retains the existing assignment. Processing and replay resolve that exact deployed handler; a missing version fails explicitly instead of falling back to a newer implementation.

## Failure experiments required before acceptance

| Injection point | Expected observable outcome |
| --- | --- |
| Invalid HMAC | `401`; no accepted event, job, or sensitive diagnostic output. |
| Before receipt commit | Transaction rolls back; no `202`; a source retry can be accepted later. |
| After receipt commit, before enqueue | Canonical event survives; recovery enqueues it even if the original process dies. |
| Enqueue fails after receipt commit | Accepted durable work remains discoverable; recovery eventually processes it without silent loss. |
| After enqueue, before HTTP response | A source retry resolves to the existing canonical event; duplicate jobs cause no duplicate effect. |
| After claim, before effect commit | Transaction rollback/claim expiry permits eventual recovery without a partial projection/effect pair. |
| After projection write, before effect transaction commit | Process termination rolls back projection and effect together. |
| After effect transaction commit, before queue acknowledgment | Retry observes one committed effect and retains one projection transition. |
| Overlapping worker and expired-claim recovery | One effect; stale worker cannot overwrite a newer attempt's lifecycle outcome. |
| 100 concurrent duplicate deliveries | One canonical event and one database domain effect; no unhandled uniqueness race. |
| Poison event / exhausted retries | Inspectable dead-letter outcome with bounded attempts, not an endless hot loop. |
| Authorized replay / cross-tenant replay | Authorized action is audited and recoverable; cross-tenant action is rejected without data leakage. |

The duplicate/crash/out-of-order suite must additionally pass 20 consecutive runs against MySQL. Capture raw experiment output, claim/retry settings, queue adapter settings, runtime versions, and observed recovery delays. The [receipt checkpoint](../s1-receipt-checkpoint.md) establishes invalid-signature rejection, receipt rollback, and ten-delivery canonical deduplication with 20 repetitions. It does not establish the full 100-delivery/one-effect or crash/recovery matrix above; this ADR remains proposed.

## Alternatives and consequences

A transactional outbox may become justified if experiments reveal a concrete requirement this approach cannot meet. It is not part of the initial implementation. Re-evaluate with evidence such as unacceptable recovery latency or an unrepairable durable-state gap; do not add it solely because a receipt/enqueue gap exists and is already explicitly recoverable.

The proposal accepts duplicate job execution and a delay until the recovery scheduler runs. It depends on durable MySQL state, eventual worker/recovery availability, correct eligibility queries, and transactionally protected effects. It cannot guarantee distributed exactly-once behavior or recover after unhandled database data loss.

Before changing this ADR to Accepted, link the implementation, settle claim/transaction ownership and scheduling details, and attach the failure results. See the [architecture](../architecture.md), [charter](../project-charter.md), and [roadmap](../roadmap.md).
