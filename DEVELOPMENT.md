# Development guide

Everything you need to work on the PostHog Roblox SDK: setting up the toolchain, running the
tests, linting and formatting, building the model file, and running the SDK inside Roblox Studio.
For cutting a release, see [RELEASING.md](RELEASING.md).

## Prerequisites

- **[Rokit](https://github.com/rojo-rbx/rokit)** — the toolchain manager. It installs every other
  tool (Rojo, Wally, Selene, StyLua, Lune) at the exact versions this repo pins, so you do not
  install those individually.
- **[Roblox Studio](https://create.roblox.com/)** — only needed to run the SDK at runtime. The unit
  tests run without it.
- **A PostHog project** — only needed for end-to-end verification (capturing real events). Grab the
  project API key (starts with `phc_`) from your project settings.
- **Git**.

## Getting set up

```sh
git clone https://github.com/PostHog/posthog-roblox.git
cd posthog-roblox
rokit install
```

`rokit install` reads [`rokit.toml`](rokit.toml) and downloads the pinned tool versions into your
Rokit install. Because CI installs the same way, your local tools match CI exactly.

> **Tip:** if you hit a GitHub rate limit during install, run `rokit authenticate github` and retry.

## Toolchain

All versions are pinned in [`rokit.toml`](rokit.toml).

| Tool | Version | What it does |
| ---- | ------- | ------------ |
| [Rojo](https://rojo.space) | 7.5.1 | Syncs the project into Studio (`rojo serve`) and builds the model file (`rojo build`). |
| [Wally](https://wally.run) | 0.3.2 | Package manager. Publishes the SDK and installs dependencies. |
| [Selene](https://kampfkarren.github.io/selene/) | 0.31.0 | Luau linter. |
| [StyLua](https://github.com/JohnnyMorganz/StyLua) | 2.5.2 | Luau formatter. |
| [Lune](https://lune-org.github.io/docs) | 0.10.4 | Standalone Luau runtime. Runs the unit tests outside Studio. |

## Project layout

```
src/                         # The SDK source (the published package)
  init.luau                  # Entry point: returns Server on the server, Client on the client
  Shared/                    # Pure, Roblox-free helpers (Uuid, Json, Logger, RetryPolicy, Sanitize, ...)
  Server/                    # Server-authoritative core: queue, transport, flags, autocapture, errors
    Storage/                 # Pluggable storage interface (default: in-memory)
  Client/                    # Thin client that relays calls to the server over a RemoteEvent
tests/                       # Lune unit tests + the coverage harness
ExampleProject/              # A runnable demo game that maps the SDK from ../src
docs/                        # User-facing documentation
default.project.json         # Rojo project for the SDK alone (used by build + bare serve)
```

The SDK is **server-authoritative**: only the server makes HTTP requests, and the client is treated
as untrusted. A guiding principle that shapes the code and the tests: logic that does not need
Roblox lives in a **pure leaf module** with its Roblox dependencies injected, so it can be tested
under Lune without Studio. The wiring that touches `game:GetService(...)` is confined to the
`init.luau` files.

## Quick reference

Run these from the repo root after `rokit install`:

```sh
lune run tests/runTests.luau                  # Unit tests + 100% coverage gate
selene src tests                              # Lint
stylua src tests ExampleProject               # Format (writes changes)
stylua --check src tests ExampleProject       # Check formatting without writing (what CI runs)
rojo build default.project.json --output posthog-roblox.rbxm   # Build the model file
rojo serve                                    # Serve the SDK to Studio
```

## Tests and the coverage gate

```sh
lune run tests/runTests.luau
```

The suite exercises every module that has **no Roblox dependency** (Uuid, RetryPolicy, Sanitize,
Defaults, Logger, FlagCache, ExceptionBuilder, EventQueue, Session, PlayerState, MemoryStorage).
Roblox-bound modules are verified in Studio instead (see [Running in Roblox
Studio](#running-in-roblox-studio)).

The runner enforces a **100% function-coverage gate** on those pure modules. It exits non-zero if
any test fails *or* if a single function goes uncovered, so adding a public function without a test
breaks the build. This is intentional: the pure modules are the SDK's testable core, and the gate
keeps them fully exercised.

### Writing a test

Specs live in `tests/<Module>.spec.luau` and use the tiny harness in
[`tests/helper.luau`](tests/helper.luau):

```luau
local helper = require("./helper")
local MyModule = require("../src/Shared/MyModule")

helper.test("does the thing", function()
    helper.expectEqual(MyModule.double(2), 4, "double(2) should be 4")
end)
```

Available assertions: `expect(condition, msg?)`, `expectEqual(actual, expected, msg?)` (deep table
compare), `expectTrue`, `expectFalse`, `expectNil`.

To bring a **new pure module** under the coverage gate, edit
[`tests/runTests.luau`](tests/runTests.luau): add a `coverage.instrument("MyModule",
require("../src/.../MyModule"))` line *before the requires*, then add `require("./MyModule.spec")`
to the spec list. Instrumentation has to happen before a spec requires the module so the tests call
the instrumented copy.

## Linting and formatting

```sh
selene src tests                          # Lint
stylua src tests ExampleProject           # Auto-format
```

- **Selene** ([`selene.toml`](selene.toml)) uses the `roblox` standard library.
- **StyLua** ([`stylua.toml`](stylua.toml)): 4-space indent, 100-column width, double quotes
  preferred, always parenthesize calls.

CI runs `stylua --check` (no writes) and fails on any diff, so format before you push.

## Building the model file

```sh
rojo build default.project.json --output posthog-roblox.rbxm
```

This produces `posthog-roblox.rbxm`, the same artifact CI builds on every push and the release
workflow attaches to GitHub releases. You normally do not need it during development (`rojo serve`
is the live-edit loop), but it is useful for testing the **model-file install path** a user would
take: drag the `.rbxm` into a place instead of installing via Wally. The file is git-ignored.

## Running in Roblox Studio

Two flows, both via Rojo's live sync (install the [Rojo Studio
plugin](https://rojo.space/docs/v7/getting-started/installation/#installing-the-roblox-studio-plugin)
first):

**Sync the SDK into your own place** — from the repo root:

```sh
rojo serve
```

The root [`default.project.json`](default.project.json) maps `src/` to a single `posthog-roblox`
instance. Connect from the Rojo plugin and it appears wherever you parent it (usually
`ReplicatedStorage`).

**Run the bundled demo game** — from `ExampleProject/`:

```sh
cd ExampleProject
rojo serve
```

[`ExampleProject/default.project.json`](ExampleProject/default.project.json) builds a full
`DataModel`: it maps the live SDK source (`../src`) into `ReplicatedStorage.PostHog` and adds demo
server and client scripts, so edits to `src/` are reflected immediately. To run it:

1. Open a new baseplate in Studio and connect the Rojo plugin.
2. Set your API key in
   [`ExampleProject/src/server/PostHogDemo.server.luau`](ExampleProject/src/server/PostHogDemo.server.luau).
3. Enable HTTP: **Game Settings -> Security -> Allow HTTP Requests** (and **Allow Studio Access to API
   Services** so DataStores/HTTP work in Studio).
4. Press **Play**. Autocaptured and demo events should appear in your PostHog project's activity
   feed within a few seconds.

## Releasing

Releases are automated on a `v*` tag push: the workflow runs the tests, builds the model, publishes
to Wally, and creates a GitHub release. See [RELEASING.md](RELEASING.md) for the full procedure.
