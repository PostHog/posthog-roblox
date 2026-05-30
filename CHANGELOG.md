# Changelog

All notable changes to the PostHog Roblox SDK are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-30

### Added

- Initial beta release.
- Event capture and batching to the PostHog `/batch` endpoint.
- Per-player identity using the Roblox `UserId` as the `distinct_id`.
- Server-authoritative architecture with a thin client relay over a `RemoteEvent`.
- Server API accepts an explicit subject (Player, UserId, distinct_id, or server-scoped).
- Feature flags via the `/flags?v=2` endpoint with per-player caching and
  `$feature_flag_called` tracking.
- Error tracking via `ScriptContext.Error` producing PostHog `$exception` events.
- Lifecycle autocapture (`player_joined` / `player_left`) with session continuation
  across teleports.
- In-memory event queue flushed on an interval and on `game:BindToClose()`.
- Pluggable storage interface (in-memory by default).
