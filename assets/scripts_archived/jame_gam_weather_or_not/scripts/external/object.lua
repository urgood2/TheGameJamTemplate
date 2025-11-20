--------------------------------------------------------------------------------
-- object.lua
-- A tiny, zero-dep OOP helper for Lua with:
--   - single inheritance via :extend()
--   - mixins via :implement(...)
--   - instanceof checks via :is(T)
--   - callable classes via __call (Class(...) constructor sugar)
--
-- DESIGN NOTES (read me)
--   • A "class" is just a table that acts as a metatable for its instances.
--   • Instances are empty tables whose metatable is the class.
--   • Inheritance is implemented by setting a subclass's metatable to its parent.
--   • Method lookups use the usual __index chain.
--   • We copy *metamethods* (keys starting with "__") to subclasses so behaviors
--     like __tostring propagate, while regular methods inherit naturally via
--     __index. This is fast, simple, and avoids deep copies of methods.
--
-- QUICK START
--   local Object = require("object")
--
--   -- Define a class
--   local Animal = Object:extend()
--   function Animal:init(name) self.name = name end
--   function Animal:speak() print(self.name .. " makes a sound.") end
--   function Animal:__tostring() return "Animal<" .. tostring(self.name) .. ">" end
--
--   -- Subclass
--   local Dog = Animal:extend()
--   function Dog:init(name, breed)
--     -- call "super" constructor explicitly
--     Dog.super.init(self, name)
--     self.breed = breed
--   end
--   function Dog:speak() print(self.name .. " barks!") end
--
--   -- Instantiate (callable class sugar)
--   local d = Dog("Rex", "Shiba")
--   d:speak()                      --> Rex barks!
--   print(d)                       --> Animal<Rex>
--   print(d:is(Dog), d:is(Animal)) --> true  true
--
-- MIXINS
--   local CanJump = {
--     jump = function(self) print(self.name .. " jumps!") end
--   }
--   Dog:implement(CanJump)
--   d:jump() --> Rex jumps!
--
-- PITFALLS / EDGE CASES
--   • Always call parent constructors explicitly: Dog.super.init(self, ...)
--     There is no hidden "super" call.
--   • :implement(...) copies only functions, and only if the method name does
--     not already exist on the receiving class (no overrides).
--   • :is(T) walks the metatable chain, so it works for both instances and
--     classes (i.e., Dog:is(Animal) is true).
--   • If you replace a metamethod (e.g., __tostring) on a parent class *after*
--     creating subclasses, those subclasses won’t auto-update; :extend() copies
--     metamethods only once at subclass creation. Define metamethods first.
--
-- FOR TOOLING (EmmyLua / Lua LS)
--   Annotated with --- comments so editors can infer types & help you navigate.
--------------------------------------------------------------------------------

---@class Object
---@field __index table        -- Points to the class itself for method lookups.
---@field super table|nil      -- Parent class (set by :extend()).
Object = {}
Object.__index = Object

---Constructor hook. Override in subclasses. Called by __call during instantiation.
---Use to set up instance fields: function Sub:init(a,b) self.a=a; self.b=b end
function Object:init() end

---Create a subclass that inherits from this class.
---Metamethods (keys beginning with "__") are copied at creation time so
---tostring/call/arith behaviors propagate; methods inherit via __index.
---@return table cls The newly created subclass.
function Object:extend()
  local cls = {}

  -- Copy *only* metamethods from parent (e.g., __tostring, __call, etc.).
  -- Regular methods flow through __index; copying them is redundant and slower.
  for k, v in pairs(self) do
    if type(k) == "string" and k:find("^__") == 1 then
      cls[k] = v
    end
  end

  -- Instances of 'cls' will look up methods on 'cls'.
  cls.__index = cls

  -- Keep a reference to the parent for explicit super calls.
  cls.super = self

  -- Inheritance: set the subclass's metatable to the parent class.
  -- This makes lookups for missing fields on the class fall back to the parent.
  setmetatable(cls, self)

  return cls
end

---Mix in functions from one or more provider tables.
---Only copies keys whose values are functions and that don't already exist.
---Think: "copy methods if absent" (no overriding).
---@param ... table One or more mixin tables.
function Object:implement(...)
  for _, provider in pairs({...}) do
    for k, v in pairs(provider) do
      if self[k] == nil and type(v) == "function" then
        self[k] = v
      end
    end
  end
end

---`instanceof`-style check. Works on instances *and* classes.
---Examples:
---   Dog("Rex"):is(Animal)  --> true
---   Dog:is(Animal)         --> true (class relationship)
---@param T table The type (class) to test against.
---@return boolean
function Object:is(T)
  local mt = getmetatable(self)
  while mt do
    if mt == T then
      return true
    end
    mt = getmetatable(mt)
  end
  return false
end

---Default string representation. Override in subclasses if useful.
---@return string
function Object:__tostring()
  return "Object"
end

---Make classes callable. Calling a class constructs an instance, sets the
---instance metatable to the class, then calls :init(...) on the instance.
---This enables:  local obj = MyClass(args...)
---@param ... any Arguments forwarded to :init(...)
---@return table obj A new instance with metatable = class.
function Object:__call(...)
  local obj = setmetatable({}, self)
  obj:init(...)
  return obj
end

--------------------------------------------------------------------------------
-- OPTIONAL PATTERNS (UNCOMMENT IF YOU WANT THEM)
--------------------------------------------------------------------------------
-- 1) Explicit .new(...) factory (identical behavior to calling the class).
--    Keep commented if you want to enforce one idiom (callable classes).
-- function Object:new(...)
--   return self(...)
-- end
--
-- 2) Simple "abstract" marker (dev-time guard). Call in :init() of a base type.
-- function Object:error_if_base_instantiated()
--   if rawget(self, "__is_abstract__") then
--     error("Attempted to instantiate abstract class: " .. tostring(self), 2)
--   end
-- end
--
-- 3) Shallow "seal" class (prevent further extension). Pure dev-time hint.
-- function Object:seal()
--   rawset(self, "__sealed__", true)
--   local parent_extend = self.extend
--   function self:extend()
--     error("Class is sealed and cannot be extended: " .. tostring(self), 2)
--   end
-- end
--------------------------------------------------------------------------------

return Object
