---
posthog-roblox: patch
---

Remove only the events that were actually sent after a flush. Previously, events captured while a full queue was flushing could be evicted and the wrong events removed, losing them.
