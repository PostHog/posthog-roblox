---
posthog-roblox: minor
---

Add a `beforeSend` config callback that can modify or drop every fully built event before it is queued. If the callback errors, the event is dropped.
