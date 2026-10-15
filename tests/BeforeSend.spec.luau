--!nonstrict
local h = require("./helper")
local BeforeSend = require("../src/Server/BeforeSend")

local function recordingLogger()
    local logger = { errors = {} }
    function logger:debug() end
    function logger:error(message)
        table.insert(self.errors, message)
    end
    return logger
end

local function event()
    return { uuid = "u", event = "signup", distinct_id = "d", timestamp = "t", properties = {} }
end

h.test("BeforeSend: passes the event through without a hook", function()
    local original = event()
    h.expect(BeforeSend.run(nil, original, recordingLogger()) == original)
end)

h.test("BeforeSend: returns the event the hook returns", function()
    local result = BeforeSend.run(function(e)
        e.properties.plan = "pro"
        return e
    end, event(), recordingLogger())
    h.expectEqual(result.properties.plan, "pro")
end)

h.test("BeforeSend: returns a replacement event", function()
    local replacement = event()
    replacement.event = "renamed"
    local result = BeforeSend.run(function()
        return replacement
    end, event(), recordingLogger())
    h.expect(result == replacement)
end)

for _, case in
    {
        { name = "nil", value = nil },
        { name = "false", value = false },
        { name = "a string", value = "signup" },
    }
do
    h.test(`BeforeSend: drops the event when the hook returns {case.name}`, function()
        local logger = recordingLogger()
        h.expectNil(BeforeSend.run(function()
            return case.value
        end, event(), logger))
        h.expectEqual(#logger.errors, 0)
    end)
end

h.test("BeforeSend: drops the event and logs when the hook throws", function()
    local logger = recordingLogger()
    h.expectNil(BeforeSend.run(function()
        error("boom")
    end, event(), logger))
    h.expectEqual(#logger.errors, 1)
end)

return true
