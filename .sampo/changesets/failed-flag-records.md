---
posthog-roblox: patch
---

Exclude failed detailed feature flags and their flat mirrors from cached values and payloads. Honor caller defaults and report failed-read diagnostics, preserving successful cached values only on response-wide errored refreshes.
