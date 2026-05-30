We want to add support for RobloxTS to use this SDK as well. I have some rough AI slop notes i'll put down below if they are useful to you, if not just figure it out on your own.

To publish a Luau SDK as a reusable npm package for the roblox-ts ecosystem, you need to bundle your Lua code, compile your TypeScript types, and structure your project so it can be installed via npm i.Here is the exact blueprint to build, structure, and publish a public roblox-ts package.1. Initialize the Package ProjectDo not develop this inside your game project. Create a completely brand-new directory for your SDK library.Run these commands in your terminal:bashmkdir my-roblox-sdk
cd my-roblox-sdk
npm init -y
npm i -D roblox-ts typescript
npx rbxtsc --init
Use code with caution.2. Configure tsconfig.jsonYour tsconfig.json must be configured for a library rather than a game. Ensure your file contains these specific keys:json{
  "compilerOptions": {
    "target": "ESNext",
    "module": "commonjs",
    "declaration": true,                    // Generates the required .d.ts files
    "outDir": "out",                        // Where compiled files go
    "rootDir": "src",
    "baseUrl": "src",
    "types": ["@rbxts/types"]
  },
  "include": ["src/**/*"]
}
Use code with caution.3. Structure Your Source FilesPlace your code inside the src folder. Because roblox-ts copies files directly during compilation, you must name your Lua file with a .lua extension and your definitions file with a .d.ts extension.textmy-roblox-sdk/
├── src/
│   ├── init.lua        <-- Your Lua SDK code
│   └── init.d.ts       <-- Your TypeScript bindings (Must use 'export =')
├── package.json
└── tsconfig.json
Use code with caution.4. Configure package.json for NPMYou must tell npm exactly which files to include in the download, and point roblox-ts to your entry files. Update your package.json:json{
  "name": "@your-username/my-roblox-sdk",
  "version": "1.0.0",
  "main": "out/init.lua",                    // Points to compiled Lua folder
  "types": "out/init.d.ts",                  // Points to compiled types folder
  "files": [
    "out/"                                   // Only publish the out folder
  ],
  "scripts": {
    "build": "rbxtsc"                        // Compiles and copies everything to /out
  },
  "peerDependencies": {
    "@rbxts/compiler-types": ">=2.0.0"       // Ensures roblox-ts version compatibility
  }
}
Use code with caution.5. Build and PublishRun the build script to compile your package. roblox-ts will automatically pull your .lua file and your .d.ts file into the out/ directory.bashnpm run build
Use code with caution.Verify that your out/ folder contains both init.lua and init.d.ts. Once verified, log into npm and publish your package to the world:bashnpm login
npm publish --access public
Use code with caution.How End-Users Will Consume ItOnce published, any roblox-ts developer can install your SDK in their game project by running npm i @your-username/my-roblox-sdk. The rbxtsc compiler will automatically find the Lua code, move it into their Roblox ReplicatedStorage or ServerScriptService upon compilation, and give them full auto-complete via your .d.ts file.