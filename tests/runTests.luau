--!nonstrict
-- Runs the unit test suite under lune and enforces the coverage gate:
--
--   lune run tests/runTests.luau
--
-- Exits non-zero when any test fails OR function coverage drops below the threshold.
-- These specs exercise every module that has no Roblox dependency. Roblox-bound
-- modules are verified in Studio (see docs/getting-started.md and the README runbook).

local process = require("@lune/process")
local helper = require("./helper")
local coverage = require("./coverage")

local COVERAGE_THRESHOLD = 100

-- Instrument BEFORE the specs require these modules so the cached, instrumented
-- tables are what the tests call.
coverage.instrument("Uuid", require("../src/Shared/Uuid"))
coverage.instrument("RetryPolicy", require("../src/Shared/RetryPolicy"))
coverage.instrument("Sanitize", require("../src/Shared/Sanitize"))
coverage.instrument("Defaults", require("../src/Shared/Defaults"))
coverage.instrument("Logger", require("../src/Shared/Logger"))
coverage.instrument("FlagCache", require("../src/Server/FlagCache"))
coverage.instrument("ExceptionBuilder", require("../src/Server/ExceptionBuilder"))
coverage.instrument("EventQueue", require("../src/Server/EventQueue"))
coverage.instrument("Session", require("../src/Server/Session"))
coverage.instrument("PlayerState", require("../src/Server/PlayerState"))
coverage.instrument("MemoryStorage", require("../src/Server/Storage/MemoryStorage"))

require("./Uuid.spec")
require("./RetryPolicy.spec")
require("./FlagCache.spec")
require("./ExceptionBuilder.spec")
require("./EventQueue.spec")
require("./Sanitize.spec")
require("./Defaults.spec")
require("./Logger.spec")
require("./Session.spec")
require("./PlayerState.spec")
require("./MemoryStorage.spec")

print("PostHog Roblox SDK - unit tests\n")

local testsOk = helper.run()
local coverageOk = coverage.report(COVERAGE_THRESHOLD)

if not testsOk then
    print("\nFAILED: one or more tests failed")
end
if not coverageOk then
    print(`\nFAILED: function coverage below {COVERAGE_THRESHOLD}%`)
end

if not (testsOk and coverageOk) then
    process.exit(1)
end

print("\nAll tests passed and coverage gate satisfied.")
