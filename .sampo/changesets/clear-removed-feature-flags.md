---
posthog-roblox: patch
---

Clear cached feature flags that are missing from an error-free `/flags` response, so a flag disabled in PostHog falls back to the default after `ReloadFeatureFlags` instead of keeping its last value. Responses with `errorsWhileComputingFlags` are still merged: flags marked as failed or missing from the response keep their previous value.
