---
posthog-roblox: minor
---

`CaptureException` (server and client) now accepts a structured `{ type?, message, trace? }` error in addition to a message string, so exceptions can carry a custom `$exception_type`. Manual client exceptions are now reported as handled.
