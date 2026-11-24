## 1.5.0

- **Breaking:** `restrictProcessing(password)` takes the account password, which the API requires (it answered 400 without it)
- `status()` reads the JSON `/health` endpoint; `/status` is an HTML page
- `addMember()` defaults to the `viewer` role
- `testPipeline()` sends `{"payload": ...}` and `updateRetentionPolicy()` sends `{"retention_policy": ...}`
- `createPipeline()` accepts the `webhookId` the API requires
- Path parameters are percent-encoded
- Every HTTP attempt has a time limit (`timeout`, default 30 seconds); a timed-out attempt is retried like a network error
- README: warning against embedding the project API key in client apps
- Declared `lints` in `dev_dependencies` (used by `analysis_options.yaml`)

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
