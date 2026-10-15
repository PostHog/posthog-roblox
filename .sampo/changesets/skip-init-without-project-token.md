---
posthog-roblox: patch
---

`Init` now logs a warning and skips setup instead of raising when `projectToken` is missing or blank, so a place without a token no longer breaks the server script.
