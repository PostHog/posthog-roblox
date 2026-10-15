---
posthog-roblox: patch
---

Drop a single event that the server rejects as too large (413) instead of retrying it forever and blocking the queue, and shrink the batch size from the rejected batch rather than the configured maximum.
