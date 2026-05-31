# Releasing

Releases are automated by [`.github/workflows/release.yml`](.github/workflows/release.yml),
which triggers on a `v*` tag.

## One-time setup

Add a `WALLY_TOKEN` repository secret (Settings -> Secrets and variables -> Actions). Generate it by
running `wally login` locally and copying the token from `~/.wally/auth.toml`.

## Cutting a release

1. Bump `version` in [`wally.toml`](wally.toml) and `SdkVersion` in
   [`src/Shared/Version.luau`](src/Shared/Version.luau) to the same value.
2. Commit, then tag with the matching version and push the tag:

   ```sh
   git tag v0.1.0
   git push origin v0.1.0
   ```

The workflow runs the test + coverage gate, builds `posthog-roblox.rbxm`, publishes to the Wally
registry, and creates a GitHub release with the model attached.
