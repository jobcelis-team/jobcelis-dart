## 1.4.0

- Automatic retries with exponential backoff for network errors and HTTP 429/502/503/504 (`maxRetries`, default 6)
- `sendEvent()` sends an `X-Idempotency-Key` (generated, or the new `idempotencyKey` argument) and `sendEvents()` adds an `idempotency_key` to every event without one, so retries never duplicate events

## 1.3.0

- Added `updateTokenRestrictions()` to limit the API token to scopes and client IPs

## 1.0.1

- Added example file for pub.dev scoring
- Added dartdoc comments to all public constructors (100% API coverage)

## 1.0.0

- Initial release with full API coverage (84+ routes)
- HTTP client using `package:http`
- HMAC-SHA256 webhook signature verification
- Dart 3.0+ / Flutter compatible
