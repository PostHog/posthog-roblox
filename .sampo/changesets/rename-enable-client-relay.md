---
posthog-roblox: minor
---

Rename the `enableClientRelay` config option to `allowClientEvents` to make its scope clear: it only gates whether the server accepts events relayed from clients, never server-side capture. `enableClientRelay` is still accepted as a deprecated alias and logs a warning; it will be removed in 1.0.
