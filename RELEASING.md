# Releasing

Releases follow the
[PostHog SDK release process](https://posthog.com/handbook/engineering/sdks/releases) and use
[sampo](https://github.com/PostHog/sampo) for version management and changelog generation. The
version lives in the root `package.json` (a stub manifest that exists only so sampo has a package
to version; the SDK has no JavaScript dependencies) and is synced to `wally.toml` and
`src/Shared/Version.luau` automatically at release time:

1. Add a changeset to your PR describing the change.
2. Merge the PR. After a maintainer approves the release, GitHub Actions handles the rest.

## Adding a changeset

When you make a change that should be included in the next release, add a markdown file to
`.sampo/changesets/` (any file name works):

```markdown
---
posthog-roblox: patch
---

A short, user-facing description of the change.
```

Follow [Semantic Versioning](https://semver.org/): **patch** for backwards-compatible bug fixes,
**minor** for backwards-compatible features, **major** for breaking changes.

If you have the [sampo CLI](https://github.com/PostHog/sampo) installed (`cargo install sampo`),
`sampo add` creates the file interactively.

## Release process

When a PR containing a changeset is merged to `main`, the release workflow
([`.github/workflows/release.yml`](.github/workflows/release.yml)):

1. Detects pending changesets in `.sampo/changesets/`.
2. Sends a Slack notification to `#approvals-client-libraries` requesting approval.
3. On approval (via the `Release` GitHub environment):
   - Runs `sampo release`: bumps `package.json`, updates `CHANGELOG.md` and removes the consumed
     changesets.
   - Syncs the version to `wally.toml` and `src/Shared/Version.luau` via `scripts/bump-version.sh`.
   - Runs the test + coverage gate.
   - Commits the version bump to `main` and creates a `vX.Y.Z` tag.
   - Builds `posthog-roblox.rbxm` and publishes the package to the Wally registry.
   - Creates a GitHub release with the model attached and notes from the changelog.

You can also trigger the workflow manually from the
[Actions tab](../../actions/workflows/release.yml) via **Run workflow**.

## One-time setup

The release workflow needs these repository secrets and variables (Settings -> Secrets and
variables -> Actions):

| Name | Type | Purpose |
| --- | --- | --- |
| `WALLY_TOKEN` | secret | wally.run API token (`wally login`, then copy from `~/.wally/auth.toml`). |
| `GH_APP_POSTHOG_ROBLOX_RELEASER_APP_ID` | secret | GitHub App used to push the version-bump commit and tag to `main`. |
| `GH_APP_POSTHOG_ROBLOX_RELEASER_PRIVATE_KEY` | secret | Private key for the same GitHub App. |
| `SLACK_CLIENT_LIBRARIES_BOT_TOKEN` | secret | Slack bot token for approval notifications (shared org secret). |
| `POSTHOG_PROJECT_API_KEY` | secret | Used by the approval-notification workflow. |
| `SLACK_APPROVALS_CLIENT_LIBRARIES_CHANNEL_ID` | variable | Slack channel for approval requests. |
| `GROUP_CLIENT_LIBRARIES_SLACK_GROUP_ID` | variable | Slack user group to ping for approvals. |

### Release environment

The `Release` environment gates the version-bump job. Per the handbook it must be configured with:

- Required reviewers: `PostHog/client-libraries-approvers` and `PostHog/team-client-libraries`
  (both teams need at least write access on the repository).
- **Prevent self-review** enabled.
- **Allow administrators to bypass configured protection rules** disabled.

### GitHub App and ruleset bypass

`main` is protected by a "Require pull request" ruleset, so the version-bump job cannot push the
release commit with the default `GITHUB_TOKEN`. It authenticates as a GitHub App instead:

1. Create (or reuse) a GitHub App named `Releaser (posthog-roblox)` with **Contents: read and
   write** repository permission, install it on this repo only, and store its client ID and a
   private key as the `GH_APP_POSTHOG_ROBLOX_RELEASER_*` secrets above.
2. Add that App as a **bypass actor** on the "Require pull request" ruleset
   (Settings -> Rules -> Rulesets -> Require pull request -> Bypass list) and on the CodeQL
   ruleset if present. Without this the `Commit version bump` step fails with a rule-violation
   error.

## Version pinning for users

Users install a specific version through Wally:

```toml
[dependencies]
PostHog = "posthog/posthog-roblox@0.1.7"
```

Or download a specific `posthog-roblox.rbxm` from the
[releases page](https://github.com/PostHog/posthog-roblox/releases).

## Troubleshooting

### Release workflow didn't trigger

It only triggers when a PR that adds a `.sampo/changesets/*.md` file is merged to `main`, or when
run manually via **Run workflow**.

### "No changesets found"

Ensure your PR includes a changeset file in `.sampo/changesets/`. See
[Adding a changeset](#adding-a-changeset).
