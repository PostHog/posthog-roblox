---
posthog-roblox: minor
---

Rename the `apiKey` config option to `projectToken` to match the cross-SDK setup spec. `apiKey` is still accepted as a deprecated alias and logs a warning; it will be removed in 1.0.
