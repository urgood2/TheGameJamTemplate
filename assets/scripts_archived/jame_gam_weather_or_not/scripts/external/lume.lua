--
-- lume
--
-- Copyright (c) 2020 rxi
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--

--[[
-- @module lume
-- @description A general-purpose utility library for Lua.
-- It provides a set of functions that extend Lua's built-in capabilities,
-- with a focus on functional programming and data manipulation. The library
-- includes helpers for math, table manipulation, string processing, and more.
-- @author rxi
-- @version 2.3.0
-- @license MIT
--]]

local lume = { _version = "2.3.0" }

-- Localized Globals
local pairs, ipairs = pairs, ipairs
local type, assert, unpack = type, assert, unpack or table.unpack
local tostring, tonumber = tostring, tonumber
local math_floor = math.floor
local math_ceil = math.ceil
local math_atan2 = math.atan2 or math.atan
local math_sqrt = math.sqrt
local math_abs = math.abs

-- Internal helper function: Does nothing.
local noop = function()
end

-- Internal helper function: Returns the first argument it receives.
local identity = function(x)
  return x
end

-- Internal helper function: Escapes Lua pattern special characters in a string.
local patternescape = function(str)
  return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
end

-- Internal helper function: Converts a negative index to a positive one.
local absindex = function(len, i)
  return i < 0 and (len + i + 1) or i
end

-- Internal helper function: Checks if a value is a function or has a `__call` metamethod.
local iscallable = function(x)
  if type(x) == "function" then return true end
  local mt = getmetatable(x)
  return mt and mt.__call ~= nil
end

-- Internal helper function: Gets an appropriate iterator (ipairs for array, pairs for table).
local getiter = function(x)
  if lume.isarray(x) then
    return ipairs
  elseif type(x) == "table" then
    return pairs
  end
  error("expected table", 3)
end

-- Internal helper function: Generates an iteratee function.
-- Used by other functions to handle different predicate types (function, table, value).
local iteratee = function(x)
  if x == nil then return identity end
  if iscallable(x) then return x end
  if type(x) == "table" then
    return function(z)
      for k, v in pairs(x) do
        if z[k] ~= v then return false end
      end
      return true
    end
  end
  return function(z) return z[x] end
end


-- //===========================================================================
-- // Math
-- //===========================================================================

--[[
-- Clamps a number between a minimum and maximum value.
-- @param x The number to clamp.
-- @param min The minimum value.
-- @param max The maximum value.
-- @return The clamped number.
--]]
function lume.clamp(x, min, max)
  return x < min and min or (x > max and max or x)
end

--[[
-- Rounds a number to the nearest integer or to the nearest increment.
-- @param x The number to round.
-- @param increment (optional) The increment to round to.
-- @return The rounded number.
--]]
function lume.round(x, increment)
  if increment then return lume.round(x / increment) * increment end
  return x >= 0 and math_floor(x + .5) or math_ceil(x - .5)
end

--[[
-- Returns the sign of a number.
-- @param x The number.
-- @return -1 if the number is negative, 1 otherwise.
--]]
function lume.sign(x)
  return x < 0 and -1 or 1
end

--[[
-- Performs linear interpolation between two numbers.
-- @param a The first number.
-- @param b The second number.
-- @param amount The interpolation amount (clamped between 0 and 1).
-- @return The interpolated number.
--]]
function lume.lerp(a, b, amount)
  return a + (b - a) * lume.clamp(amount, 0, 1)
end

--[[
-- Performs smooth interpolation between two numbers using a cubic Hermite spline.
-- @param a The first number.
-- @param b The second number.
-- @param amount The interpolation amount (clamped between 0 and 1).
-- @return The smoothly interpolated number.
--]]
function lume.smooth(a, b, amount)
  local t = lume.clamp(amount, 0, 1)
  local m = t * t * (3 - 2 * t)
  return a + (b - a) * m
end

--[[
-- Creates a "ping-pong" effect, where a value moves back and forth between 0 and 1.
-- @param x The input value.
-- @return A number between 0 and 1.
--]]
function lume.pingpong(x)
  return 1 - math_abs(1 - x % 2)
end

--[[
-- Calculates the distance between two points.
-- @param x1 The x-coordinate of the first point.
-- @param y1 The y-coordinate of the first point.
-- @param x2 The x-coordinate of the second point.
-- @param y2 The y-coordinate of the second point.
-- @param squared (optional) If true, returns the squared distance.
-- @return The distance or squared distance.
--]]
function lume.distance(x1, y1, x2, y2, squared)
  local dx = x1 - x2
  local dy = y1 - y2
  local s = dx * dx + dy * dy
  return squared and s or math_sqrt(s)
end

--[[
-- Calculates the angle in radians between two points.
-- @param x1 The x-coordinate of the first point.
-- @param y1 The y-coordinate of the first point.
-- @param x2 The x-coordinate of the second point.
-- @param y2 The y-coordinate of the second point.
-- @return The angle in radians.
--]]
function lume.angle(x1, y1, x2, y2)
  return math_atan2(y2 - y1, x2 - x1)
end

--[[
-- Converts an angle and magnitude into a 2D vector.
-- @param angle The angle in radians.
-- @param magnitude The magnitude of the vector.
-- @return The x and y components of the vector.
--]]
function lume.vector(angle, magnitude)
  return math.cos(angle) * magnitude, math.sin(angle) * magnitude
end

--[[
-- Generates a random floating-point number in a given range.
-- @param a (optional) The minimum value (default is 0).
-- @param b (optional) The maximum value (default is 1).
-- @return A random number.
--]]
function lume.random(a, b)
  if not a then a, b = 0, 1 end
  if not b then b = 0 end
  return a + math.random() * (b - a)
end

--[[
-- Returns a random element from an array.
-- @param t The array.
-- @return A random element from the array.
--]]
function lume.randomchoice(t)
  return t[math.random(#t)]
end

--[[
-- Selects a random key from a table where the values are weights.
-- @param t A table where keys are items and values are their weights.
-- @return A random key from the table, chosen based on weight.
--]]
function lume.weightedchoice(t)
  local sum = 0
  for _, v in pairs(t) do
    assert(v >= 0, "weight value less than zero")
    sum = sum + v
  end
  assert(sum ~= 0, "all weights are zero")
  local rnd = lume.random(sum)
  for k, v in pairs(t) do
    if rnd < v then return k end
    rnd = rnd - v
  end
end


-- //===========================================================================
-- // Table
-- //===========================================================================

--[[
-- Checks if a value is an array-like table (has a value at index 1).
-- @param x The value to check.
-- @return `true` if the value is an array, `false` otherwise.
--]]
function lume.isarray(x)
  return type(x) == "table" and x[1] ~= nil
end

--[[
-- Appends one or more values to the end of an array. Modifies the table in-place.
-- @param t The array to push values to.
-- @param ... The values to append.
-- @return The appended values.
--]]
function lume.push(t, ...)
  local n = select("#", ...)
  for i = 1, n do
    t[#t + 1] = select(i, ...)
  end
  return ...
end

--[[
-- Removes the first occurrence of a value from a table. Modifies the table in-place.
-- @param t The table.
-- @param x The value to remove.
-- @return The value that was removed.
--]]
function lume.remove(t, x)
  local iter = getiter(t)
  for i, v in iter(t) do
    if v == x then
      if lume.isarray(t) then
        table.remove(t, i)
        break
      else
        t[i] = nil
        break
      end
    end
  end
  return x
end

--[[
-- Removes all key-value pairs from a table. Modifies the table in-place.
-- @param t The table to clear.
-- @return The cleared table.
--]]
function lume.clear(t)
  local iter = getiter(t)
  for k in iter(t) do
    t[k] = nil
  end
  return t
end

--[[
-- Copies key-value pairs from one or more source tables into a target table.
-- Modifies the target table in-place.
-- @param t The target table.
-- @param ... The source table(s).
-- @return The modified target table.
--]]
function lume.extend(t, ...)
  for i = 1, select("#", ...) do
    local x = select(i, ...)
    if x then
      for k, v in pairs(x) do
        t[k] = v
      end
    end
  end
  return t
end

--[[
-- Creates a new array with the elements of an existing array in a random order.
-- @param t The array to shuffle.
-- @return A new, shuffled array.
--]]
function lume.shuffle(t)
  local rtn = {}
  for i = 1, #t do
    local r = math.random(i)
    if r ~= i then
      rtn[i] = rtn[r]
    end
    rtn[r] = t[i]
  end
  return rtn
end

--[[
-- Creates a sorted copy of an array.
-- @param t The array to sort.
-- @param comp (optional) A comparison function or a string specifying a key to sort by.
-- @return A new, sorted array.
--]]
function lume.sort(t, comp)
  local rtn = lume.clone(t)
  if comp then
    if type(comp) == "string" then
      table.sort(rtn, function(a, b) return a[comp] < b[comp] end)
    else
      table.sort(rtn, comp)
    end
  else
    table.sort(rtn)
  end
  return rtn
end

--[[
-- Creates a new array from a list of arguments.
-- @param ... The values to include in the array.
-- @return A new array containing the given values.
--]]
function lume.array(...)
  local t = {}
  for x in ... do t[#t + 1] = x end
  return t
end

--[[
-- Iterates over a table and calls a function for each element.
-- @param t The table to iterate over.
-- @param fn The function to call for each element. Can be a function or the name of a method.
-- @param ... Additional arguments to pass to the function.
-- @return The original table.
--]]
function lume.each(t, fn, ...)
  local iter = getiter(t)
  if type(fn) == "string" then
    for _, v in iter(t) do v[fn](v, ...) end
  else
    for _, v in iter(t) do fn(v, ...) end
  end
  return t
end

--[[
-- Creates a new table by applying a function to each element of a table.
-- @param t The table to map over.
-- @param fn The function to apply to each element.
-- @return A new table with the results.
--]]
function lume.map(t, fn)
  fn = iteratee(fn)
  local iter = getiter(t)
  local rtn = {}
  for k, v in iter(t) do rtn[k] = fn(v) end
  return rtn
end

--[[
-- Checks if a function returns true for all elements in a table.
-- @param t The table to check.
-- @param fn The predicate function.
-- @return `true` if all elements pass the test, `false` otherwise.
--]]
function lume.all(t, fn)
  fn = iteratee(fn)
  local iter = getiter(t)
  for _, v in iter(t) do
    if not fn(v) then return false end
  end
  return true
end

--[[
-- Checks if a function returns true for at least one element in a table.
-- @param t The table to check.
-- @param fn The predicate function.
-- @return `true` if any element passes the test, `false` otherwise.
--]]
function lume.any(t, fn)
  fn = iteratee(fn)
  local iter = getiter(t)
  for _, v in iter(t) do
    if fn(v) then return true end
  end
  return false
end

--[[
-- Reduces a table to a single value by repeatedly applying a function.
-- @param t The table to reduce.
-- @param fn The function to apply: `function(accumulator, value)`.
-- @param first (optional) The initial value of the accumulator.
-- @return The final accumulated value.
--]]
function lume.reduce(t, fn, first)
  local started = first ~= nil
  local acc = first
  local iter = getiter(t)
  for _, v in iter(t) do
    if started then
      acc = fn(acc, v)
    else
      acc = v
      started = true
    end
  end
  assert(started, "reduce of an empty table with no first value")
  return acc
end

--[[
-- Creates a new array containing only the unique values from a table.
-- @param t The table.
-- @return A new array with unique values.
--]]
function lume.unique(t)
  local rtn = {}
  for k in pairs(lume.invert(t)) do
    rtn[#rtn + 1] = k
  end
  return rtn
end

--[[
-- Creates a new table with all the elements that pass a test.
-- @param t The table to filter.
-- @param fn The predicate function.
-- @param retainkeys (optional) If true, preserves the original keys.
-- @return A new, filtered table.
--]]
function lume.filter(t, fn, retainkeys)
  fn = iteratee(fn)
  local iter = getiter(t)
  local rtn = {}
  if retainkeys then
    for k, v in iter(t) do
      if fn(v) then rtn[k] = v end
    end
  else
    for _, v in iter(t) do
      if fn(v) then rtn[#rtn + 1] = v end
    end
  end
  return rtn
end

--[[
-- Creates a new table with all the elements that do not pass a test.
-- @param t The table to filter.
-- @param fn The predicate function.
-- @param retainkeys (optional) If true, preserves the original keys.
-- @return A new, filtered table.
--]]
function lume.reject(t, fn, retainkeys)
  fn = iteratee(fn)
  local iter = getiter(t)
  local rtn = {}
  if retainkeys then
    for k, v in iter(t) do
      if not fn(v) then rtn[k] = v end
    end
  else
    for _, v in iter(t) do
      if not fn(v) then rtn[#rtn + 1] = v end
    end
  end
  return rtn
end

--[[
-- Creates a new table by merging multiple tables. Last-in wins for conflicting keys.
-- @param ... The tables to merge.
-- @return A new, merged table.
--]]
function lume.merge(...)
  local rtn = {}
  for i = 1, select("#", ...) do
    local t = select(i, ...)
    local iter = getiter(t)
    for k, v in iter(t) do
      rtn[k] = v
    end
  end
  return rtn
end

--[[
-- Creates a new array by concatenating multiple arrays.
-- @param ... The arrays to concatenate.
-- @return A new, concatenated array.
--]]
function lume.concat(...)
  local rtn = {}
  for i = 1, select("#", ...) do
    local t = select(i, ...)
    if t ~= nil then
      local iter = getiter(t)
      for _, v in iter(t) do
        rtn[#rtn + 1] = v
      end
    end
  end
  return rtn
end

--[[
-- Finds the key of the first occurrence of a value in a table.
-- @param t The table.
-- @param value The value to find.
-- @return The key of the found value, or nil if not found.
--]]
function lume.find(t, value)
  local iter = getiter(t)
  for k, v in iter(t) do
    if v == value then return k end
  end
  return nil
end

--[[
-- Returns the first value and its key from a table that matches a predicate.
-- @param t The table.
-- @param fn The predicate function.
-- @return The value and its key, or nil if not found.
--]]
function lume.match(t, fn)
  fn = iteratee(fn)
  local iter = getiter(t)
  for k, v in iter(t) do
    if fn(v) then return v, k end
  end
  return nil
end

--[[
-- Counts the number of elements in a table.
-- If a function is provided, it counts the elements for which the function returns true.
-- @param t The table.
-- @param fn (optional) The predicate function.
-- @return The count.
--]]
function lume.count(t, fn)
  local count = 0
  local iter = getiter(t)
  if fn then
    fn = iteratee(fn)
    for _, v in iter(t) do
      if fn(v) then count = count + 1 end
    end
  else
    if lume.isarray(t) then
      return #t
    end
    for _ in iter(t) do count = count + 1 end
  end
  return count
end

--[[
-- Extracts a slice of an array.
-- @param t The array.
-- @param i The starting index (can be negative).
-- @param j (optional) The ending index (can be negative).
-- @return A new array containing the slice.
--]]
function lume.slice(t, i, j)
  i = i and absindex(#t, i) or 1
  j = j and absindex(#t, j) or #t
  local rtn = {}
  for x = i < 1 and 1 or i, j > #t and #t or j do
    rtn[#rtn + 1] = t[x]
  end
  return rtn
end

--[[
-- Returns the first element of an array, or the first n elements.
-- @param t The array.
-- @param n (optional) The number of elements to return.
-- @return The first element, or a new array of the first n elements.
--]]
function lume.first(t, n)
  if not n then return t[1] end
  return lume.slice(t, 1, n)
end

--[[
-- Returns the last element of an array, or the last n elements.
-- @param t The array.
-- @param n (optional) The number of elements to return.
-- @return The last element, or a new array of the last n elements.
--]]
function lume.last(t, n)
  if not n then return t[#t] end
  return lume.slice(t, -n, -1)
end

--[[
-- Creates a new table where the keys and values are swapped.
-- @param t The table.
-- @return A new table with keys and values inverted.
--]]
function lume.invert(t)
  local rtn = {}
  for k, v in pairs(t) do rtn[v] = k end
  return rtn
end

--[[
-- Creates a new table with a subset of key-value pairs from a table.
-- @param t The table.
-- @param ... The keys to pick.
-- @return A new table with the picked key-value pairs.
--]]
function lume.pick(t, ...)
  local rtn = {}
  for i = 1, select("#", ...) do
    local k = select(i, ...)
    rtn[k] = t[k]
  end
  return rtn
end

--[[
-- Creates a new array containing the keys of a table.
-- @param t The table.
-- @return A new array of keys.
--]]
function lume.keys(t)
  local rtn = {}
  local iter = getiter(t)
  for k in iter(t) do rtn[#rtn + 1] = k end
  return rtn
end

--[[
-- Creates a shallow copy of a table.
-- @param t The table to clone.
-- @return A new, shallow copy of the table.
--]]
function lume.clone(t)
  local rtn = {}
  for k, v in pairs(t) do rtn[k] = v end
  return rtn
end


-- //===========================================================================
-- // Function
-- //===========================================================================

--[[
-- Creates a new function that will call the original function with predefined arguments.
-- @param fn The function to wrap.
-- @param ... The arguments to pre-apply.
-- @return A new function.
--]]
function lume.fn(fn, ...)
  assert(iscallable(fn), "expected a function as the first argument")
  local args = { ... }
  return function(...)
    local a = lume.concat(args, { ... })
    return fn(unpack(a))
  end
end

--[[
-- Creates a function that can only be called once.
-- @param fn The function to wrap.
-- @param ... Arguments to pass to the function.
-- @return A new function that will only execute once.
--]]
function lume.once(fn, ...)
  local f = lume.fn(fn, ...)
  local done = false
  return function(...)
    if done then return end
    done = true
    return f(...)
  end
end


local memoize_fnkey = {}
local memoize_nil = {}

--[[
-- Returns a memoized version of a function. Caches the results of function calls.
-- @param fn The function to memoize.
-- @return A new, memoized function.
--]]
function lume.memoize(fn)
  local cache = {}
  return function(...)
    local c = cache
    for i = 1, select("#", ...) do
      local a = select(i, ...) or memoize_nil
      c[a] = c[a] or {}
      c = c[a]
    end
    c[memoize_fnkey] = c[memoize_fnkey] or {fn(...)}
    return unpack(c[memoize_fnkey])
  end
end

--[[
-- Combines multiple functions into a single function that calls them in sequence.
-- @param ... The functions to combine.
-- @return A new function that calls all the provided functions.
--]]
function lume.combine(...)
  local n = select('#', ...)
  if n == 0 then return noop end
  if n == 1 then
    local fn = select(1, ...)
    if not fn then return noop end
    assert(iscallable(fn), "expected a function or nil")
    return fn
  end
  local funcs = {}
  for i = 1, n do
    local fn = select(i, ...)
    if fn ~= nil then
      assert(iscallable(fn), "expected a function or nil")
      funcs[#funcs + 1] = fn
    end
  end
  return function(...)
    for _, f in ipairs(funcs) do f(...) end
  end
end

--[[
-- Calls a function with given arguments, if the function is not nil.
-- @param fn The function to call.
-- @param ... Arguments to pass to the function.
-- @return The result of the function call, or nil.
--]]
function lume.call(fn, ...)
  if fn then
    return fn(...)
  end
end

--[[
-- Measures the execution time of a function.
-- @param fn The function to time.
-- @param ... Arguments to pass to the function.
-- @return The execution time in seconds, followed by the function's return values.
--]]
function lume.time(fn, ...)
  local start = os.clock()
  local rtn = {fn(...)}
  return (os.clock() - start), unpack(rtn)
end


-- //===========================================================================
-- // String & Serialization
-- //===========================================================================

local lambda_cache = {}

--[[
-- Compiles a string into a Lua function.
-- @param str A string in the format "args -> body".
-- @return The compiled function.
--]]
function lume.lambda(str)
  if not lambda_cache[str] then
    local args, body = str:match([[^([%w,_ ]-)%->(.-)$]])
    assert(args and body, "bad string lambda")
    local s = "return function(" .. args .. ")\nreturn " .. body .. "\nend"
    lambda_cache[str] = lume.dostring(s)
  end
  return lambda_cache[str]
end


local serialize

local serialize_map = {
  [ "boolean" ] = tostring,
  [ "nil"     ] = tostring,
  [ "string"  ] = function(v) return string.format("%q", v) end,
  [ "number"  ] = function(v)
    if      v ~=  v     then return  "0/0"      --  nan
    elseif  v ==  1 / 0 then return  "1/0"      --  inf
    elseif  v == -1 / 0 then return "-1/0" end  -- -inf
    return tostring(v)
  end,
  [ "table"   ] = function(t, stk)
    stk = stk or {}
    if stk[t] then error("circular reference") end
    local rtn = {}
    stk[t] = true
    for k, v in pairs(t) do
      rtn[#rtn + 1] = "[" .. serialize(k, stk) .. "]=" .. serialize(v, stk)
    end
    stk[t] = nil
    return "{" .. table.concat(rtn, ",") .. "}"
  end
}

setmetatable(serialize_map, {
  __index = function(_, k) error("unsupported serialize type: " .. k) end
})

serialize = function(x, stk)
  return serialize_map[type(x)](x, stk)
end

--[[
-- Serializes a Lua value into a string. Handles numbers, strings, booleans, nils, and tables.
-- Detects circular references in tables.
-- @param x The value to serialize.
-- @return The serialized string.
--]]
function lume.serialize(x)
  return serialize(x)
end

--[[
-- Deserializes a string created by `lume.serialize` back into a Lua value.
-- @param str The string to deserialize.
-- @return The deserialized Lua value.
--]]
function lume.deserialize(str)
  return lume.dostring("return " .. str)
end

--[[
-- Splits a string by a separator.
-- @param str The string to split.
-- @param sep (optional) The separator pattern. If nil, splits by whitespace.
-- @return An array of the split parts.
--]]
function lume.split(str, sep)
  if not sep then
    return lume.array(str:gmatch("([%S]+)"))
  else
    assert(sep ~= "", "empty separator")
    local psep = patternescape(sep)
    return lume.array((str..sep):gmatch("(.-)("..psep..")"))
  end
end

--[[
-- Removes leading and trailing whitespace or a specified set of characters from a string.
-- @param str The string to trim.
-- @param chars (optional) A string of characters to trim.
-- @return The trimmed string.
--]]
function lume.trim(str, chars)
  if not chars then return str:match("^[%s]*(.-)[%s]*$") end
  chars = patternescape(chars)
  return str:match("^[" .. chars .. "]*(.-)[" .. chars .. "]*$")
end

--[[
-- Wraps a string to a given line limit.
-- @param str The string to wrap.
-- @param limit (optional) The line length limit (default is 72). Can be a number or a function.
-- @return The word-wrapped string.
--]]
function lume.wordwrap(str, limit)
  limit = limit or 72
  local check
  if type(limit) == "number" then
    check = function(s) return #s >= limit end
  else
    check = limit
  end
  local rtn = {}
  local line = ""
  for word, spaces in str:gmatch("(%S+)(%s*)") do
    local s = line .. word
    if check(s) then
      table.insert(rtn, line .. "\n")
      line = word
    else
      line = s
    end
    for c in spaces:gmatch(".") do
      if c == "\n" then
        table.insert(rtn, line .. "\n")
        line = ""
      else
        line = line .. c
      end
    end
  end
  table.insert(rtn, line)
  return table.concat(rtn)
end

--[[
-- Formats a string by replacing placeholders like `{key}` with values from a table.
-- @param str The string with placeholders.
-- @param vars A table of values to substitute.
-- @return The formatted string.
--]]
function lume.format(str, vars)
  if not vars then return str end
  local f = function(x)
    return tostring(vars[x] or vars[tonumber(x)] or "{" .. x .. "}")
  end
  return (str:gsub("{(.-)}", f))
end


-- //===========================================================================
-- // Miscellaneous
-- //===========================================================================

--[[
-- Prints debug information, including file, line number, and given values.
-- @param ... The values to trace.
--]]
function lume.trace(...)
  local info = debug.getinfo(2, "Sl")
  local t = { info.short_src .. ":" .. info.currentline .. ":" }
  for i = 1, select("#", ...) do
    local x = select(i, ...)
    if type(x) == "number" then
      x = string.format("%g", lume.round(x, .01))
    end
    t[#t + 1] = tostring(x)
  end
  print(table.concat(t, " "))
end

--[[
-- A cross-compatible version of `loadstring` or `load` that executes a string of Lua code.
-- @param str The string of Lua code to execute.
-- @return The result of the executed code.
--]]
function lume.dostring(str)
  return assert((loadstring or load)(str))()
end

--[[
-- Generates a version 4 UUID (Universally Unique Identifier).
-- @return A UUID string.
--]]
function lume.uuid()
  local fn = function(x)
    local r = math.random(16) - 1
    r = (x == "x") and (r + 1) or (r % 4) + 9
    return ("0123456789abcdef"):sub(r, r)
  end
  return (("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"):gsub("[xy]", fn))
end

--[[
-- Attempts to hot-swap a Lua module by reloading it and updating existing references.
-- @param modname The name of the module to hotswap.
-- @return The module table, or nil and an error message on failure.
--]]
function lume.hotswap(modname)
  local oldglobal = lume.clone(_G)
  local updated = {}
  local function update(old, new)
    if updated[old] then return end
    updated[old] = true
    local oldmt, newmt = getmetatable(old), getmetatable(new)
    if oldmt and newmt then update(oldmt, newmt) end
    for k, v in pairs(new) do
      if type(v) == "table" then update(old[k], v) else old[k] = v end
    end
  end
  local err = nil
  local function onerror(e)
    for k in pairs(_G) do _G[k] = oldglobal[k] end
    err = lume.trim(e)
  end
  local ok, oldmod = pcall(require, modname)
  oldmod = ok and oldmod or nil
  xpcall(function()
    package.loaded[modname] = nil
    local newmod = require(modname)
    if type(oldmod) == "table" then update(oldmod, newmod) end
    for k, v in pairs(oldglobal) do
      if v ~= _G[k] and type(v) == "table" then
        update(v, _G[k])
        _G[k] = v
      end
    end
  end, onerror)
  package.loaded[modname] = oldmod
  if err then return nil, err end
  return oldmod
end


-- Internal iterator for `ripairs`.
local ripairs_iter = function(t, i)
  i = i - 1
  local v = t[i]
  if v ~= nil then
    return i, v
  end
end

--[[
-- Returns an iterator for iterating over an array in reverse order.
-- @param t The array to iterate over.
-- @return An iterator function, the table, and the initial index.
--]]
function lume.ripairs(t)
  return ripairs_iter, t, (#t + 1)
end

--[[
-- Parses a color string and returns its RGBA components.
-- @param str The color string (e.g., "#ff0000", "rgb(255,0,0)", "rgba(255,0,0,0.5)").
-- @param mul (optional) A multiplier for the RGB components (default is 1).
-- @return r, g, b, a components (as numbers between 0 and 1).
--]]
function lume.color(str, mul)
  mul = mul or 1
  local r, g, b, a
  r, g, b = str:match("#(%x%x)(%x%x)(%x%x)")
  if r then
    r = tonumber(r, 16) / 0xff
    g = tonumber(g, 16) / 0xff
    b = tonumber(b, 16) / 0xff
    a = 1
  elseif str:match("rgba?%s*%([%d%s%.,]+%)") then
    local f = str:gmatch("[%d.]+")
    r = (f() or 0) / 0xff
    g = (f() or 0) / 0xff
    b = (f() or 0) / 0xff
    a = f() or 1
  else
    error(("bad color string '%s'"):format(str))
  end
  return r * mul, g * mul, b * mul, a * mul
end


-- //===========================================================================
-- // Chaining
-- //===========================================================================

local chain_mt = {}
chain_mt.__index = lume.map(lume.filter(lume, iscallable, true),
  function(fn)
    return function(self, ...)
      self._value = fn(self._value, ...)
      return self
    end
  end)

--[[
-- @description Unwraps the chained value and returns the final result.
-- Should be called at the end of a chain.
--]]
chain_mt.__index.result = function(x) return x._value end

--[[
-- Starts a lume chain, which allows for a fluent interface.
-- @param value The initial value to wrap.
-- @return A chainable object.
--]]
function lume.chain(value)
  return setmetatable({ _value = value }, chain_mt)
end

-- Set the metatable for the main `lume` table. This allows `lume(...)` to be
-- called as a function, which initiates a chain.
setmetatable(lume,  {
  __call = function(_, ...)
    return lume.chain(...)
  end
})


return lume