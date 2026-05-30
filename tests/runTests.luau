--!nonstrict
-- Runs the pure-logic unit test suite under lune:
--
--   lune run tests/runTests.luau
--
-- These specs exercise the modules that have no Roblox dependency (Uuid, FlagCache,
-- ExceptionBuilder, RetryPolicy, EventQueue). Modules that touch Roblox APIs are
-- verified in Studio (see the README runbook).

local process = require("@lune/process")
local helper = require("./helper")

require("./Uuid.spec")
require("./RetryPolicy.spec")
require("./FlagCache.spec")
require("./ExceptionBuilder.spec")
require("./EventQueue.spec")
require("./Sanitize.spec")

print("PostHog Roblox SDK - unit tests\n")

local ok = helper.run()
if not ok then
    process.exit(1)
end
