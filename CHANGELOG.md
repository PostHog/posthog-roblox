# posthog-roblox

## 0.2.0 — 2026-10-15

### Minor changes

- [77df0da](https://github.com/posthog/posthog-roblox/commit/77df0da893d0ec199bdf63600a16a80f1ef456b6) Rename the `apiKey` config option to `projectToken` to match the cross-SDK setup spec. `apiKey` is still accepted as a deprecated alias and logs a warning; it will be removed in 1.0. — Thanks @charlesvien!
- [77df0da](https://github.com/posthog/posthog-roblox/commit/77df0da893d0ec199bdf63600a16a80f1ef456b6) Retry feature flag requests after network errors and 502 or 504 responses, with backoff starting at 300ms. Add the `featureFlagRequestMaxRetries` config option (default 1, `0` disables retries). — Thanks @charlesvien!
- [77df0da](https://github.com/posthog/posthog-roblox/commit/77df0da893d0ec199bdf63600a16a80f1ef456b6) Add a `beforeSend` config callback that can modify or drop every fully built event before it is queued. If the callback errors, the event is dropped. — Thanks @charlesvien!
- [2ea9000](https://github.com/posthog/posthog-roblox/commit/2ea9000e51056db8885d791f348e89e22c822466) `CaptureException` (server and client) now accepts a structured `{ type?, message, trace? }` error in addition to a message string, so exceptions can carry a custom `$exception_type`. Manual client exceptions are now reported as handled. — Thanks @charlesvien!
- [2ea9000](https://github.com/posthog/posthog-roblox/commit/2ea9000e51056db8885d791f348e89e22c822466) Export `Subject` and `ExceptionInput` types, annotate every server method signature with them and document how to use stable external ids alongside players. — Thanks @charlesvien!
- [2ea9000](https://github.com/posthog/posthog-roblox/commit/2ea9000e51056db8885d791f348e89e22c822466) Rename the `enableClientRelay` config option to `allowClientEvents` to make its scope clear: it only gates whether the server accepts events relayed from clients, never server-side capture. `enableClientRelay` is still accepted as a deprecated alias and logs a warning; it will be removed in 1.0. — Thanks @charlesvien!

### Patch changes

- [77df0da](https://github.com/posthog/posthog-roblox/commit/77df0da893d0ec199bdf63600a16a80f1ef456b6) Retry event batches that receive a 408 or 429 response instead of dropping them. — Thanks @charlesvien!
- [2ea9000](https://github.com/posthog/posthog-roblox/commit/2ea9000e51056db8885d791f348e89e22c822466) Migrate release tooling from JS changesets to sampo. Contributing no longer requires a JavaScript toolchain. — Thanks @charlesvien!
- [77df0da](https://github.com/posthog/posthog-roblox/commit/77df0da893d0ec199bdf63600a16a80f1ef456b6) Remove only the events that were actually sent after a flush. Previously, events captured while a full queue was flushing could be evicted and the wrong events removed, losing them. — Thanks @charlesvien!
- [77df0da](https://github.com/posthog/posthog-roblox/commit/77df0da893d0ec199bdf63600a16a80f1ef456b6) `Init` now logs a warning and skips setup instead of raising when `projectToken` is missing or blank, so a place without a token no longer breaks the server script. — Thanks @charlesvien!
- [77df0da](https://github.com/posthog/posthog-roblox/commit/77df0da893d0ec199bdf63600a16a80f1ef456b6) Drop a single event that the server rejects as too large (413) instead of retrying it forever and blocking the queue, and shrink the batch size from the rejected batch rather than the configured maximum. — Thanks @charlesvien!

## 0.1.7

### Patch Changes

- b4c3aab: Fix the release workflow so merging a changeset publishes to Wally without a GitHub App.

## 0.1.6

### Patch Changes

- Migrate versioning and release automation to changesets.

## 0.1.5

- Beta release.
