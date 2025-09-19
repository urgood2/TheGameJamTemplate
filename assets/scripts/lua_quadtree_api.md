# Quadtree Lua API

Two `WorldQuadtree` instances are injected into Lua:

* `quadtreeWorld` → spatial index for world entities
* `quadtreeUI` → spatial index for UI entities

---

## Box

A `Box` is just a Lua table:

```lua
{ left = number, top = number, width = number, height = number }
```

Or use the helper:

```lua
local b1 = quadtree.box(0, 0, 64, 64)
local b2 = quadtree.box({ left=10, top=20, width=30, height=40 })
```

---

## Methods on WorldQuadtree

* **`clear()`** → remove all entities
* **`add(e)`** → insert an entity (must have an AABB on C++ side)
* **`remove(e)`** → remove an entity
* **`query(box)`** → return entities intersecting the box
* **`find_all_intersections()`** → return intersecting pairs `{ {a,b}, ... }`
* **`get_bounds()`** → return quadtree bounds as a `Box`

---

## Example

```lua
-- Query world quadtree
local hits = quadtreeWorld:query(quadtree.box(0,0,128,128))
for _, e in ipairs(hits) do
    print("Found entity:", e)
end

-- Check all intersections
for _, pair in ipairs(quadtreeUI:find_all_intersections()) do
    print("UI overlap between:", pair[1], pair[2])
end

-- Clear the UI tree
quadtreeUI:clear()
```
