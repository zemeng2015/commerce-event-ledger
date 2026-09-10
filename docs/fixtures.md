# Synthetic order-create fixture

The offline fixture exercises a narrow Shopify `orders/create` contract without customer data or a Shopify account. Normalization and fixture publishing alone do not prove authentication, durable receipt, deduplication, or a committed order effect. The [HTTP receipt implementation](http-receipt.md) adds actual authentication and canonical storage; the [processing checkpoint](s1-processing-checkpoint.md) adds asynchronous transactional order effects.

## Run without a store or database

With Ruby 4.0.6, from the checkout:

```sh
ruby bin/publish_fixture --dry-run
```

This validates invocation/metadata and signs the committed fixture bytes without sending a request. It does not certify body schema or persistence; normalization tests validate the committed body separately. The JSON summary reports the event identity, byte length, body digest, and requested count. It omits the body, signature, and secret. The publisher uses Ruby's standard libraries and does not boot Rails or connect to MySQL.

The equivalent command in the development image is:

```sh
docker compose run --rm --no-deps app ruby bin/publish_fixture --dry-run
```

Build the image first with `docker compose build app`. The `--no-deps` option keeps this dry run independent of the database service.

With the development HTTP receiver running locally, send ten deliveries with:

```sh
ruby bin/publish_fixture --count 10
```

The default destination is `http://127.0.0.1:3000/webhooks/shopify/fixture`. For Docker, use `docker compose exec -T app ruby bin/publish_fixture --count 10`. The development receiver commits a canonical pending event before returning `202`. Publisher byte fidelity is also tested against a temporary loopback receiver. The jobs service asynchronously commits the order effect. CI verifies ten deliveries and one effect on a fresh stack; a reusable demo command and clean-clone timing remain pending.

## Repeatability and transport behavior

The publisher reads `fixtures/shopify/orders_create.json` as bytes and signs those exact bytes with Base64-encoded HMAC-SHA256. It never parses and reserializes the transmitted body. UTF-8 text, whitespace, and the final newline therefore participate in the signature.

The committed metadata supplies a deterministic `X-Shopify-Event-Id`. Every delivery in a run—and every repeated run with the default fixture—uses that same event ID and body. Each delivery gets a fresh `X-Shopify-Webhook-Id`. Use `--event-id` with an explicit UUID to start another synthetic event; changing that value does not create a new order identity in the payload.

`--count` accepts 1 through 100. `--url` accepts literal loopback HTTP destinations only (`127.0.0.1` or `[::1]`), without credentials, a query, or a fragment. Requests bypass environment proxies, have bounded timeouts, do not follow redirects, and do not retry automatically. The publisher requires `202` and stops on the first failure. Its acceptance count reports HTTP responses, not independently verified database durability.

The default signing value, `ledger-fixture-secret-do-not-use-outside-local`, is public synthetic configuration. `LEDGER_FIXTURE_SECRET` can override it in the invoking process; the matching local source configuration must use the same value. Do not pass real credentials on the command line or commit them. The fixture shop domain is a synthetic routing label and does not cause traffic to Shopify.

## Normalization contract

`Webhooks::ShopifyOrderCreate#call(raw_body:, headers:, source_configuration:)` returns the immutable `EventLedger::Envelope`. The required `Webhooks::ShopifySource` is constructed by trusted server configuration with an internal positive `shop_id`, canonical `myshopify.com` domain, and explicit secret. Its inspection and default JSON representation are redacted. A source object and a normalizer call alone do not authenticate a request; the ingress must verify HMAC before calling normalization.

| Input | Required interpretation |
| --- | --- |
| `X-Shopify-Topic` | Exactly `orders/create` |
| `X-Shopify-API-Version` | `2026-07`, the explicitly supported fixture/adapter version |
| `X-Shopify-Shop-Domain` | Matches the trusted source configuration |
| `X-Shopify-Event-Id` | Opaque merchant-action identifier, 1–200 printable non-space ASCII bytes; preserved without case folding or a delivery-ID fallback |
| JSON `id` | Positive integer, retained exactly as a decimal string for the external order identity |
| JSON `created_at`, `updated_at` | Valid calendar timestamps in RFC 3339 form, with explicit offsets, seconds 00–59, and at most nanosecond precision; update time cannot precede creation |

Header names are case-insensitive; ambiguous duplicate spellings of a required header are rejected. The input must be a UTF-8 JSON object no larger than 1 MiB, with bounded nesting and no duplicate object keys. Malformed values fail with a generic normalization error without the request body or secret.

The normalized payload contains only `order_id`, `state` (`created`), `created_at`, and `updated_at`. Timestamps are canonical UTC strings with nine fractional digits. Customer objects, addresses, email, prices, notes, and other source fields are discarded. The envelope's `subject_id` is the decimal order ID and `payload_sha256` is SHA-256 of the original bytes.

## Event identity and ordering

The canonical external event identity is `orders/create:<X-Shopify-Event-Id>`, with source `shopify` and the trusted internal shop ID. Topic qualification prevents distinct supported topics from being collapsed under the same merchant-action identity when later topics are added. `X-Shopify-Webhook-Id` identifies a delivery and is not the canonical key. The source identifier remains recoverable from the documented qualification; it is not replaced by a random internal ID. Only the synthetic publisher's optional event-ID argument requires a UUID; normalization does not assume that format for provider identities.

`occurred_at` uses the resource's `updated_at`, and `source_version` is `nil`: the adapter does not invent a monotonically increasing version from delivery time. `X-Shopify-Triggered-At`, local receipt time, and arrival order are not used as the resource version. Future projection code must define stale/equal timestamp handling explicitly and preserve source precision; normalization does not establish non-regression by itself.

These choices follow Shopify's [webhook delivery metadata and ordering guidance](https://shopify.dev/docs/apps/build/webhooks) and the [2026-07 webhook reference](https://shopify.dev/docs/api/webhooks/2026-07). Shopify's [HTTPS webhook guidance](https://shopify.dev/docs/apps/build/webhooks/subscribe/https) defines the raw-body HMAC format. A real development-store delivery remains an independent, unmet integration gate.
