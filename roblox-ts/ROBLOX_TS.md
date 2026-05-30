We want to add support for RobloxTS to use this SDK as well. I have some rough AI slop notes i'll put down below if they are useful to you, if not just figure it out on your own.

To use a standard Luau/Lua SDK inside roblox-ts, you do not need to rewrite the code. Instead, you need to create TypeScript type definitions (a .d.ts file). This tells the roblox-ts compiler exactly what functions, arguments, and data types exist in your Lua code.Here is the step-by-step process to create bindings and make your Lua SDK fully compatible.1. Structure Your FilesPlace your existing Lua SDK directly into your project's source folder (usually src). You must place a TypeScript declaration file with the exact same name right next to it.textsrc/
├── MyLuaSDK.lua       <-- Your actual Lua SDK code
└── MyLuaSDK.d.ts      <-- Your TypeScript bindings file
Use code with caution.2. Write the Type Bindings (.d.ts)Inside your .d.ts file, you will describe the shape of the Lua module using TypeScript syntax.For example, if your Lua SDK looks like this:lua-- MyLuaSDK.lua
local SDK = {}

function SDK.init(config)
    print("Initialized with " .. config.apiKey)
    return true
end

function SDK.getUserData(userId)
    return { name = "Player", id = userId }
Use code with caution.Your corresponding TypeScript declaration file must look like this:typescript// MyLuaSDK.d.ts

// 1. Define the interfaces for your data shapes
interface SDKConfig {
    apiKey: string;
}

interface UserData {
    name: string;
    id: number;
}

// 2. Define the namespace or object structure matching the Lua return
declare namespace MyLuaSDK {
    function init(config: SDKConfig): boolean;
    function getUserData(userId: number): UserData;
}

// 3. Export the module so roblox-ts can import it
export = MyLuaSDK;
Use code with caution.3. Consume the SDK in TypeScriptOnce the .d.ts file is saved, roblox-ts will automatically pair it with the .lua file. You can now import and use your Lua SDK with full autocompletion and type safety.typescript// src/server/main.ts
import MyLuaSDK from "../MyLuaSDK";

const success = MyLuaSDK.init({ apiKey: "12345-abc" });

if (success) {
    const data = MyLuaSDK.getUserData(112233);
    print(data.name); // Intelligently autocompletes 'name' and 'id'
}
Use code with caution.Important Compatibility RulesTable Indexing: Lua arrays start at 1, but roblox-ts arrays start at 0. If your Lua SDK returns a standard numerical array, type it as a Luau LuaTuple or handle the 0/1 offset carefully in your TS code.Methods vs. Functions:If your Lua SDK uses a colon (SDK:DoSomething()), type it as a normal method in TS: DoSomething(): void;.If your Lua SDK uses a dot (SDK.DoSomething()), type it as a property function in TS: DoSomething: (this: void) => void;. The this: void tells TypeScript not to pass the object itself as the first implicit argument.