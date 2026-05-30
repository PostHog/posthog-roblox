--!nonstrict
-- Tiny test harness. Specs register tests with `test(...)`; the runner calls `run()`.
-- Pure Luau, runnable under lune with no Roblox dependency.

local Helper = {}
local tests = {}

local function deepEqual(a: any, b: any): boolean
    if a == b then
        return true
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    for key, value in a do
        if not deepEqual(value, b[key]) then
            return false
        end
    end
    for key in b do
        if a[key] == nil then
            return false
        end
    end
    return true
end

local function show(value: any): string
    if type(value) == "table" then
        local parts = {}
        for key, item in value do
            table.insert(parts, `{tostring(key)}={tostring(item)}`)
        end
        return "{ " .. table.concat(parts, ", ") .. " }"
    end
    return tostring(value)
end

function Helper.test(name: string, fn: () -> ())
    table.insert(tests, { name = name, fn = fn })
end

function Helper.expect(condition: any, message: string?)
    if not condition then
        error(message or "expectation failed", 2)
    end
end

function Helper.expectEqual(actual: any, expected: any, message: string?)
    if not deepEqual(actual, expected) then
        error(
            string.format(
                "%s\n      expected: %s\n      actual:   %s",
                message or "values differ",
                show(expected),
                show(actual)
            ),
            2
        )
    end
end

function Helper.expectTrue(value: any, message: string?)
    if value ~= true then
        error(message or `expected true, got {tostring(value)}`, 2)
    end
end

function Helper.expectFalse(value: any, message: string?)
    if value ~= false then
        error(message or `expected false, got {tostring(value)}`, 2)
    end
end

function Helper.expectNil(value: any, message: string?)
    if value ~= nil then
        error(message or `expected nil, got {tostring(value)}`, 2)
    end
end

function Helper.run(): boolean
    local passed, failed = 0, 0
    for _, entry in tests do
        local ok, err = pcall(entry.fn)
        if ok then
            passed += 1
            print(`  ok   {entry.name}`)
        else
            failed += 1
            print(`  FAIL {entry.name}`)
            print(`       {tostring(err)}`)
        end
    end
    print(`\n{passed} passed, {failed} failed, {passed + failed} total`)
    return failed == 0
end

return Helper
