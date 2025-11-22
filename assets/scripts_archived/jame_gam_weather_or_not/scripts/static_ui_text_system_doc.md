# Static UI Text — Quick Usage (Lua + C++)

A fast, ID-based way to address UI text/segments created from your coded-string parser. Build an id→entity map once, then do O(1) lookups from Lua.

---

## What this gives you

* Deterministic **IDs** for every text, image, and wrapper segment.
* Post-instantiation **scan** that builds a `TextUIHandle` with `idMap`.
* Lua helpers to **fetch/mutate** nodes by ID without walking the tree.

---

## Prerequisites

* Each instantiated UI node stores its string **id** in `ui::UIConfig.id`.
* Your hierarchy uses `transform::GameObject.orderedChildren`.

---

## C++ one-liner scan

Use the built-in default traversal (no callbacks needed):

```cpp
TextUIHandleLua handle;
buildIdMapFromRootDefault(globals::getRegistry(), rootEntity, handle);
```

This depth-first scans from `rootEntity`, collects all nodes with `UIConfig.id`, and fills `handle.idMap`.

> Fallback IDs are auto-generated as `L{line}S{seg}` (and `wrap-L{line}S{seg}` for wrappers) if no explicit `id=` is present.

---

## Lua API (under `ui.text`)

### Build / Rebuild

```lua
local handle = ui.text.buildIdMapDefault(root)   -- returns TextUIHandle
-- ... later, after re-instantiating the subtree ...
handle = ui.text.buildIdMapDefault(root)
```

### Query

```lua
local e = ui.text.getNode(handle, "stringID")   -- Entity or nil
local count = ui.text.size(handle)               -- integer
for _, id in ipairs(ui.text.keys(handle)) do     -- string[]
  log_debug("id:", id)
end
```

### Mutate (example convenience)

```lua
ui.text.setColor(handle, "stringID", "LIME")    -- returns boolean
```

### Debug IDs from a raw string

```lua
ui.text.debugDumpIdsFromString([[Hello [world](id=mySeg;color=RED)]])
```

---

## Quickstart (end-to-end)

```lua
-- 1) Define your coded string
local def = ui.definitions.getTextFromString([[ 
[Hello here's a longer test](id=stringID,color=LIME;background=gray)\n
World Test
]])

-- 2) Instantiate your UI box (example; use your own function)
local root = ui.create_box_from_definition(def)

-- 3) Build the id map (DFS over GameObject.orderedChildren)
local handle = ui.text.buildIdMapDefault(root)

-- 4) O(1) lookup + mutate
if ui.text.getNode(handle, "stringID") then
  ui.text.setColor(handle, "stringID", "LIME")
end

-- 5) Inspect
log_debug("total ids:", ui.text.size(handle))
for _, id in ipairs(ui.text.keys(handle)) do log_debug(id) end
```

---

## Authoring IDs in text

* Explicit: `[Segment Text](id=title;color=YELLOW;background=BLACK)`
* Image: `[img](uuid=gear.png;scale=0.8;fg=WHITE;shadow=false)` → node gets `id` if provided.
* Animation: `[anim](uuid=idle_animation;scale=1.0;fg=WHITE)`
* Wrapper `id`: When `background=...` is present, the wrapper gets its own ID; if no explicit id, it uses `wrap-L{line}S{seg}`.

---

## When you must rebuild

Rebuild the map any time you:

* Recreate the UI subtree from a template.
* Change which nodes exist or their `UIConfig.id`.

```lua
handle = ui.text.buildIdMapDefault(newRoot)
```

---

## Common patterns

**Toggle highlight**

```lua
local id = "stringID"
if ui.text.getNode(handle, id) then
  ui.text.setColor(handle, id, "YELLOW")
end
```

**Batch update**

```lua
for _, id in ipairs(ui.text.keys(handle)) do
  ui.text.setColor(handle, id, "WHITE")
end
```

---

## Troubleshooting

* **`getNode` returns nil**: ID not present; call `ui.text.keys(handle)` to inspect. Ensure `UIConfig.id` is set during creation.
* **Nothing found after rebuild**: Check that `root` is valid and your hierarchy actually uses `transform::GameObject.orderedChildren`.
* **Colors don’t apply**: Confirm node type uses `UIConfig.color` (text/object path) and that `util::getColor(name)` recognizes your value.

---

## Reference (C++)

* `buildIdMapFromRootDefault(registry, root, TextUIHandleLua&)`
* `resolveNodeId(...): string` → explicit `id` or fallback `L{line}S{seg}` / `wrap-L{line}S{seg}`
* `getTextFromString(text) -> UIElementTemplateNode` assigns ids to nodes during build
* `debugDumpIds(parsed)` logs segment and wrapper IDs

That’s it. Build once, index
