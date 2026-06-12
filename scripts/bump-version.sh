#!/usr/bin/env bash

# ./scripts/bump-version.sh <new version>
# eg ./scripts/bump-version.sh "0.2.0"
#
# Syncs the version from the root package.json (managed by sampo) to every
# file that hardcodes the SDK version:
#   - wally.toml                  package manifest version
#   - src/Shared/Version.luau     runtime SdkVersion constant
#   - README.md                   Wally dependency example
#   - docs/getting-started.md     Wally dependency example
#   - RELEASING.md                Wally dependency example
#   - ExampleProject/wally.toml   example package version + pinned SDK dependency
#
# Wally dependency references must carry an explicit "@<version>" suffix, so the
# examples are pinned to the current release and bumped here in lockstep.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

NEW_VERSION="$1"

NEW_VERSION="$NEW_VERSION" node -e '
  const fs = require("fs");
  const v = process.env.NEW_VERSION;

  // Replace each pattern once, failing loudly if it is no longer present so a
  // moved or renamed version string is caught in CI instead of silently skipped.
  const edit = (path, replacements) => {
    let text = fs.readFileSync(path, "utf8");
    for (const [pattern, replacement] of replacements) {
      const exists = new RegExp(pattern.source, pattern.flags.replace("g", ""));
      if (!exists.test(text)) {
        throw new Error(`bump-version: pattern ${pattern} not found in ${path}`);
      }
      text = text.replace(pattern, replacement);
    }
    fs.writeFileSync(path, text);
  };

  // The package manifest version (line starts with `version = `, not a dependency).
  const manifestVersion = [/^version = "[^"]*"/m, `version = "${v}"`];
  // The Wally dependency pin, matched regardless of the current version suffix.
  const dependencyPin = () => [/posthog\/posthog-roblox@[^"\s]+/g, `posthog/posthog-roblox@${v}`];

  edit("wally.toml", [manifestVersion]);
  edit("src/Shared/Version.luau", [[/SdkVersion = "[^"]*"/, `SdkVersion = "${v}"`]]);
  edit("README.md", [dependencyPin()]);
  edit("docs/getting-started.md", [dependencyPin()]);
  edit("RELEASING.md", [dependencyPin()]);
  edit("ExampleProject/wally.toml", [manifestVersion, dependencyPin()]);
'

echo "✓ Synced version $NEW_VERSION to wally.toml, src/Shared/Version.luau, README.md, docs/getting-started.md, RELEASING.md, and ExampleProject/wally.toml"
