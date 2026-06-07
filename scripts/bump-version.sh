#!/usr/bin/env bash

# ./scripts/bump-version.sh <new version>
# eg ./scripts/bump-version.sh "0.2.0"
#
# Syncs the version from the root package.json (managed by changesets) to the
# Roblox-specific files:
#   - wally.toml                  (Wally package manifest)
#   - src/Shared/Version.luau     (runtime SdkVersion constant)

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

NEW_VERSION="$1"

NEW_VERSION="$NEW_VERSION" node -e '
  const fs = require("fs");
  const v = process.env.NEW_VERSION;

  let wally = fs.readFileSync("wally.toml", "utf8");
  wally = wally.replace(/^version = "[^"]*"/m, `version = "${v}"`);
  fs.writeFileSync("wally.toml", wally);

  let version = fs.readFileSync("src/Shared/Version.luau", "utf8");
  version = version.replace(/SdkVersion = "[^"]*"/, `SdkVersion = "${v}"`);
  fs.writeFileSync("src/Shared/Version.luau", version);
'

echo "✓ Synced version $NEW_VERSION to wally.toml and src/Shared/Version.luau"
