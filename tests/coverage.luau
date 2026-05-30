--!nonstrict
-- Function-coverage gate.
--
-- Roblox's Luau has no line-level coverage hooks (debug.sethook is unavailable), so
-- this harness instruments the exported functions of the headless-testable modules:
-- it wraps each function in place to record whether it was invoked by the suite. The
-- runner then fails CI if any tracked function was never exercised (or coverage is
-- below the threshold). This forces every public function of these modules to have a
-- test. Roblox-bound modules (Transport, init, RelayServer, ...) are covered by the
-- Studio integration runbook instead.

local Coverage = {}

local registry = {}

-- Wraps every function field of `moduleTable` in place to record invocation, then
-- returns the same table for chaining.
function Coverage.instrument(name: string, moduleTable: any): any
    local fns = {}
    for key, value in moduleTable do
        if type(value) == "function" then
            fns[key] = false
            local original = value
            moduleTable[key] = function(...)
                fns[key] = true
                return original(...)
            end
        end
    end
    table.insert(registry, { name = name, fns = fns })
    return moduleTable
end

-- Prints a coverage report. Returns true when every tracked function was called and
-- the overall percentage meets `threshold`.
function Coverage.report(threshold: number): boolean
    local total, covered = 0, 0
    local missing = {}

    for _, entry in registry do
        for fnName, called in entry.fns do
            total += 1
            if called then
                covered += 1
            else
                table.insert(missing, `{entry.name}.{fnName}`)
            end
        end
    end

    local pct = if total == 0 then 100 else (covered / total) * 100
    print(`\nFunction coverage: {covered}/{total} ({string.format("%.1f", pct)}%)`)

    if #missing > 0 then
        table.sort(missing)
        print("Uncovered functions:")
        for _, name in missing do
            print(`  - {name}`)
        end
    end

    return #missing == 0 and pct >= threshold
end

return Coverage
