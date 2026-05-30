--!strict
-- UUID v7 generator (time-ordered UUIDs), ported from the PostHog Unity SDK.
--
-- The first 48 bits are a Unix millisecond timestamp, making the IDs sortable by
-- creation time. A 12-bit monotonic counter disambiguates IDs created within the
-- same millisecond. Roblox has no 64-bit integers, so the 48-bit timestamp is
-- split with plain arithmetic (Luau doubles are exact below 2^53) and the nibble /
-- variant bit twiddling uses `bit32`.
--
-- Dependencies are injected so the module is pure and unit-testable without any
-- Roblox API:
--   opts.nowMillis  -> () -> number   current Unix time in milliseconds
--   opts.randomByte -> () -> number   a random integer in [0, 255]

local Uuid = {}
Uuid.__index = Uuid

export type Generator = typeof(setmetatable(
    {} :: {
        _nowMillis: () -> number,
        _randomByte: () -> number,
        _lastTimestamp: number,
        _counter: number,
    },
    Uuid
))

local HEX = "0123456789abcdef"

local function toHex(byte: number): string
    local hi = math.floor(byte / 16) + 1
    local lo = (byte % 16) + 1
    return HEX:sub(hi, hi) .. HEX:sub(lo, lo)
end

local TWO_32 = 4294967296
local TWO_24 = 16777216
local TWO_16 = 65536

function Uuid.new(opts: { nowMillis: () -> number, randomByte: () -> number }): Generator
    assert(type(opts.nowMillis) == "function", "Uuid.new requires opts.nowMillis")
    assert(type(opts.randomByte) == "function", "Uuid.new requires opts.randomByte")
    return setmetatable({
        _nowMillis = opts.nowMillis,
        _randomByte = opts.randomByte,
        _lastTimestamp = -1,
        _counter = 0,
    }, Uuid)
end

function Uuid:generate(): string
    local timestamp = math.floor(self._nowMillis())

    if timestamp == self._lastTimestamp then
        self._counter += 1
        if self._counter > 0xFFF then
            -- Counter overflow within a millisecond; wait for the clock to advance.
            repeat
                timestamp = math.floor(self._nowMillis())
            until timestamp ~= self._lastTimestamp
            self._counter = 0
        end
    else
        self._counter = 0
    end

    self._lastTimestamp = timestamp
    local counter = self._counter

    local bytes = {}

    -- Bytes 1-6: 48-bit timestamp, big-endian.
    local high16 = math.floor(timestamp / TWO_32)
    local low32 = timestamp % TWO_32
    bytes[1] = math.floor(high16 / 256) % 256
    bytes[2] = high16 % 256
    bytes[3] = math.floor(low32 / TWO_24) % 256
    bytes[4] = math.floor(low32 / TWO_16) % 256
    bytes[5] = math.floor(low32 / 256) % 256
    bytes[6] = low32 % 256

    -- Byte 7: version (0x7) in the high nibble, top 4 bits of the counter below it.
    bytes[7] = bit32.bor(0x70, bit32.band(math.floor(counter / 256), 0x0F))
    -- Byte 8: low 8 bits of the counter.
    bytes[8] = counter % 256

    -- Bytes 9-16: random.
    for i = 9, 16 do
        bytes[i] = self._randomByte() % 256
    end
    -- Byte 9: force the RFC 4122 variant (10xxxxxx).
    bytes[9] = bit32.bor(0x80, bit32.band(bytes[9], 0x3F))

    local hex = {}
    for i = 1, 16 do
        hex[i] = toHex(bytes[i])
    end

    return table.concat({
        hex[1] .. hex[2] .. hex[3] .. hex[4],
        hex[5] .. hex[6],
        hex[7] .. hex[8],
        hex[9] .. hex[10],
        hex[11] .. hex[12] .. hex[13] .. hex[14] .. hex[15] .. hex[16],
    }, "-")
end

return Uuid
