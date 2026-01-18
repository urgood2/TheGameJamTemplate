-- bit_compat.lua
-- Provides LuaJIT-compatible bit library interface for both backends
--
-- LuaJIT:  `bit` library is built-in, this file does nothing
-- Lua 5.4: Creates `bit` table using Lua 5.3+ operators via load()
--          (load() avoids parse errors - operators are only compiled if needed)

if bit then
    -- LuaJIT: bit library already exists, nothing to do
    return
end

-- Lua 5.4: Create bit library using native operators
-- We use load() so the 5.3+ operators are only parsed when this code runs
-- (If we wrote `a | b` directly, it would fail to parse under LuaJIT)
bit = {}
bit.bor    = load("return function(a, b) return a | b end")()
bit.band   = load("return function(a, b) return a & b end")()
bit.bxor   = load("return function(a, b) return a ~ b end")()
bit.bnot   = load("return function(a) return ~a end")()
bit.lshift = load("return function(a, b) return a << b end")()
bit.rshift = load("return function(a, b) return a >> b end")()

-- Additional functions for LuaJIT API compatibility (also using load())
-- tobit normalizes to a signed 32-bit integer (like LuaJIT's bit.tobit)
bit.tobit = load([[
    return function(a)
        a = a % 0x100000000  -- Normalize to 0..2^32-1
        if a >= 0x80000000 then
            return a - 0x100000000  -- Convert to signed 32-bit
        end
        return a
    end
]])()
bit.tohex  = function(a, n)
    n = n or 8
    if n < 0 then
        return string.format("%0" .. (-n) .. "X", a)
    else
        return string.format("%0" .. n .. "x", a)
    end
end
bit.arshift = load([[
    return function(a, b)
        -- Arithmetic right shift preserves sign bit
        a = a & 0xFFFFFFFF  -- Normalize to 32-bit
        if a >= 0x80000000 then
            -- Negative: fill with 1s from the left
            return ((a >> b) | (~(0xFFFFFFFF >> b))) & 0xFFFFFFFF
        else
            return a >> b
        end
    end
]])()
bit.rol = load([[
    return function(a, b)
        b = b % 32
        return ((a << b) | (a >> (32 - b))) & 0xFFFFFFFF
    end
]])()
bit.ror = load([[
    return function(a, b)
        b = b % 32
        return ((a >> b) | (a << (32 - b))) & 0xFFFFFFFF
    end
]])()
bit.bswap = load([[
    return function(a)
        return ((a & 0xFF) << 24) |
               ((a & 0xFF00) << 8) |
               ((a & 0xFF0000) >> 8) |
               ((a & 0xFF000000) >> 24)
    end
]])()
