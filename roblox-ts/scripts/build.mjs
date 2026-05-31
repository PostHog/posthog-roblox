// Builds the publishable @rbxts/posthog package into out/.
//
// The SDK is already written in Luau, so there is nothing to compile (unlike a
// TypeScript-authored roblox-ts package). We copy the Luau source verbatim and pair
// the entry modules with hand-written .d.ts bindings:
//
//   out/init.luau        <- ../src/init.luau        (auto-detects server/client)
//   out/init.d.ts        <- bindings/init.d.ts      (server API types)
//   out/Client/init.luau <- ../src/Client/init.luau (the client relay)
//   out/Client/init.d.ts <- bindings/client.d.ts    (client API types)

import { cpSync, copyFileSync, mkdirSync, readdirSync, rmSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const packageRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const sdkSource = join(packageRoot, "..", "src");
const bindings = join(packageRoot, "bindings");
const out = join(packageRoot, "out");

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });

// 1. Copy the Luau SDK source verbatim. This preserves the module tree so every
//    relative `require(script.Parent...)` resolves the same way it does in the repo.
cpSync(sdkSource, out, { recursive: true });

// 2. Pair the entry modules with their TypeScript declaration files.
copyFileSync(join(bindings, "init.d.ts"), join(out, "init.d.ts"));
copyFileSync(join(bindings, "client.d.ts"), join(out, "Client", "init.d.ts"));

console.log("Built @rbxts/posthog:");
for (const entry of readdirSync(out)) {
	console.log(`  out/${entry}`);
}
