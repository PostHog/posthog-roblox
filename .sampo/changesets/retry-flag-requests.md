---
posthog-roblox: minor
---

Retry feature flag requests after network errors and 502 or 504 responses, with backoff starting at 300ms. Add the `featureFlagRequestMaxRetries` config option (default 1, `0` disables retries).
