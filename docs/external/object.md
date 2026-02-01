# `object.lua` Usage Guide

This guide explains how to use the tiny OOP helper (`object.lua`) in Lua. It covers classes, inheritance, mixins, type checks, and optional patterns.

---

## 📥 Importing

```lua
local Object = require("object")
```

---

## 🐾 Defining a Class

```lua
local Animal = Object:extend()

function Animal:init(name)
  self.name = name
end

function Animal:speak()
  print(self.name .. " makes a sound.")
end
```

* `Object:extend()` creates a new class.
* `:init(...)` is the constructor, automatically called when you instantiate.

**Usage:**

```lua
local a = Animal("Generic")
a:speak() --> Generic makes a sound.
```

---

## 🐶 Subclassing

```lua
local Dog = Animal:extend()

function Dog:init(name, breed)
  Dog.super.init(self, name) -- explicit parent constructor call
  self.breed = breed
end

function Dog:speak()
  print(self.name .. " barks!")
end
```

**Usage:**

```lua
local d = Dog("Rex", "Shiba")
d:speak() --> Rex barks!
```

---

## 🔧 Mixins

Mixins are simple tables of functions that can be merged into a class.

```lua
local CanJump = {
  jump = function(self)
    print(self.name .. " jumps!")
  end
}

Dog:implement(CanJump)
```

**Usage:**

```lua
d:jump() --> Rex jumps!
```

---

## 🔍 Type Checks

Check if an object (or class) is an instance of another class.

```lua
print(d:is(Dog))    --> true
print(d:is(Animal)) --> true
print(Dog:is(Animal)) --> true
```

---

## 📝 String Representations

Override `__tostring` for nice printing.

```lua
function Dog:__tostring()
  return "Dog<" .. self.name .. ", " .. self.breed .. ">"
end

print(Dog("Rex", "Shiba")) --> Dog<Rex, Shiba>
```

---

## ⚡ Callable Classes

All classes can be called like functions to create instances.

```lua
local obj = Dog("Rex", "Shiba")
```

This is sugar for:

```lua
local obj = setmetatable({}, Dog)
obj:init("Rex", "Shiba")
```

---

## 🛠 Optional Patterns

These are commented out in `object.lua`, but you can enable them:

1. **`.new(...)` factory method**

   ```lua
   local obj = MyClass:new(args)
   ```

2. **Abstract class guard**

   ```lua
   function Object:error_if_base_instantiated()
     if rawget(self, "__is_abstract__") then
       error("Attempted to instantiate abstract class")
     end
   end
   ```

3. **Sealed class (no further subclassing)**

   ```lua
   function Object:seal()
     error("Class is sealed and cannot be extended")
   end
   ```

---

## ✅ Summary

* `:extend()` → make new classes.
* `:init(...)` → constructor.
* `Class.super.init(self, ...)` → call parent constructors.
* `:implement(...)` → add mixins.
* `:is(Type)` → type checking.
* `__tostring` → customize printing.
* Callable classes → instantiate with `Class(...)`.

---

## 📂 Example Project Layout

```
project/
├── object.lua
└── example.lua
```

Run with:

```bash
lua example.lua
```

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
