# HTTP receipt

Implementation under review for issues #7 and #8. MySQL and HTTP acceptance evidence is pending; this document does not claim processing or recovery has passed.

`POST /webhooks/shopify/<route_token>` verifies HMAC-SHA256 over the exact bounded request bytes before normalization or database receipt. A strict Base64 signature is compared using OpenSSL's fixed-length constant-time comparison. The expected shop domain must match the server-owned source selected by the route capability. A body signature alone does not authenticate the shop-domain header.

Set `LEDGER_SHOPIFY_SOURCES` to a JSON array of objects containing exactly `route_token`, `shop_id`, `shop_domain`, and `secret`. Allocate a positive internal shop ID, a canonical lowercase `*.myshopify.com` domain, a cryptographically random 32-byte route capability encoded as 64 lowercase hexadecimal characters, and the webhook signing secret. Tokens, shop IDs, and domains must be unique. Generate tokens with `SecureRandom.hex(32)`. Configure Shopify to deliver to that shop's private endpoint. Never derive the tenant from request headers alone or use a public shop ID as the route capability. Shared application signing secrets still require distinct capabilities per shop.

Development and test default to the explicitly synthetic `/webhooks/shopify/fixture` source, shop ID 7, and the public fixture secret used by `bin/publish_fixture`. `LEDGER_FIXTURE_SECRET` overrides that fixture secret. Supplying `LEDGER_SHOPIFY_SOURCES` replaces the default. Production has no default and rejects the fixture token. Missing or invalid configuration fails closed with `503`. Configuration is resolved inside the Rails reloader on each request; there is no database access at boot or cached reloadable package instance.

The endpoint middleware runs before Rails request logging, exception rendering, and parameter parsing. It consumes all paths beginning with `/webhooks/shopify`, including malformed paths, and emits only fixed errors or permitted receipt fields. Any reverse proxy or hosting access logger must likewise omit or redact the private path and headers before using real credentials. The current local Puma configuration has no request access logger. This implementation does not configure an external proxy or authorize deployment.

| Result | HTTP status |
| --- | --- |
| Committed new or matching duplicate receipt | 202 |
| Unknown capability, wrong shop domain, invalid/missing HMAC | 401 |
| Authenticated malformed JSON, unsupported topic/version, invalid normalization fields | 400 |
| Same canonical identity with different original bytes or normalized attributes | 409 |
| Request body exceeds 1 MiB | 413 |
| Non-POST method | 405 |
| Unavailable database, enclosing transaction, or invalid server configuration | 503 |

Size and method limits precede cryptographic validation. The one-MiB application read limit is not a server-level upload timeout or protection against buffering by an upstream HTTP server. Error responses never reflect input. The accepted adapter remains narrowly `orders/create`, API version `2026-07`; see [normalization policy](fixtures.md).

EventLedger owns `shops` and `received_events` on the primary MySQL connection. First authenticated receipt registers the trusted shop mapping and inserts the event in one transaction. Existing tenant mappings cannot be overwritten. The unique `(shop_id, source, external_event_id)` index uses `utf8mb4_0900_bin`, preserving case-sensitive opaque identifiers. Matching duplicates increment delivery accounting under a row lock and preserve the original payload and handler assignment. Conflicts do not increment accepted-delivery accounting. The stored payload is the normalization allowlist, not the raw body; its SHA-256 digest identifies exact original bytes. Source timestamps retain nine fractional digits in a UTC string to avoid MySQL DATETIME truncation.

The receipt adapter rejects an existing enclosing transaction, ensuring it cannot return before the actual commit. Insert failures roll back shop registration and the event together. A receipt means durable pending work only. Solid Queue dispatch, effects, recovery, and GraphQL inspection are the next dependencies and remain unimplemented. Do not claim a processed order or one domain effect from receipt tests.

Verification commands: `ruby bin/test`, `bundle exec ruby script/check_coverage.rb`, `bundle exec packwerk validate`, `bundle exec packwerk check`, `bundle exec ruby script/check_package_boundaries.rb`, and the existing lint/security checks. Application CI runs the non-transactional receipt suite against native MySQL and fresh Docker MySQL. The suite uses only the fixed test database and tests ten sequential and ten concurrent deliveries, real MySQL constraint failure/rollback, cross-connection commit visibility, tenant separation, exact-byte conflicts, source precision, and sanitized request responses. A Docker publisher check sends ten actual HTTP deliveries to the development server. These checks do not replace the full 100-delivery/one-effect or process-crash acceptance gates.
