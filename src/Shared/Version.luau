--!strict
-- SDK version and library name.
-- `SdkVersion` is synced from the root package.json (managed by changesets) to
-- wally.toml and this file by scripts/bump-version.sh during release. Do not
-- edit the version by hand; add a changeset instead (see RELEASING.md).

return {
    SdkVersion = "0.1.7",
    LibraryName = "posthog-roblox",
}
