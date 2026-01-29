# Nodemap Core (Headless) — Usage Guide

This guide shows how to use **`nodemap_core_headless.lua`** to build unlockable node graphs (skill trees, world maps, etc.) with your own renderer and input.

---

## What you get

* Pure-logic graph: nodes, edges, visitability propagation, hover/click, label orientation.
* No drawing/tween libs required.
* Suggestive colors via `palette` (you can ignore and supply your own).

> API surface

* `local NM = require 'nodemap_core_headless'`
* `local graph = NM.generate(nodemap, { color_mode='skill_tree', palette=... })`
* `NM.update(graph, dt, { mx, my, m1_pressed })`
* `for n in NM.nodes(graph) do ... end` and `for e in NM.edges(graph) do ... end`

---

## 1) Define a nodemap

Each entry describes a node and its links by **id**.

```lua
local nodemap = {
  [1] = {
    x = 400, y = 300,
    links = {2,3,4,5},
    visited = true,                 -- seed starting node
    color = {0.98,0.85,0.1,1},      -- optional; your renderer may ignore
    label = 'Start',
    on_visit = function(n)
      print('Visited node', n.id)
    end,
  },
  [2] = { x=400, y=220, links={1}, label='North' },
  [3] = { x=480, y=300, links={1}, label='East'  },
  [4] = { x=400, y=380, links={1}, label='South' },
  [5] = { x=320, y=300, links={1}, label='West'  },
}
```

**Optional fields** per node: `rs` (radius, default 6), `can_be_visited` (seed visitability), `data` (arbitrary payload), `on_draw` (ignored by core; for your renderer).

---

## 2) Create a graph

```lua
local NM = require 'nodemap_core_headless'

local graph = NM.generate(nodemap, {
  color_mode = 'skill_tree',
  palette = {
    bg_dim    = {0.23,0.23,0.23,1.0},
    bg_mid    = {0.35,0.35,0.35,1.0},
    bg_bright = {0.55,0.55,0.55,1.0},
    fg        = {0.86,0.86,0.86,1.0},
  },
})
```

`color_mode` behavior:

* **`nil`**: use node color as-is; once visited it becomes dim (bg\_mid).
* **`'skill_tree'`**: unvisitable = bg\_mid, visitable = bg\_bright (or fg on hover), visited = original `src_color`.

---

## 3) Drive updates with your input

Call once per frame.

```lua
-- you supply these
local mx, my = getMouse()                 -- cursor position in world space
local clicked = mousePressedThisFrame()   -- edge-triggered

NM.update(graph, dt, { mx = mx, my = my, m1_pressed = clicked })
```

`update` handles:

* hover detection (`node.hot`)
* visitability propagation (if any neighbor is visited, a node becomes visitable)
* click-to-visit (sets `node.visited = true` and fires `node.on_visit(node)`)
* color suggestions (stored on `node.color`, `edge.color`)
* edge endpoint offsets so lines meet node rims (`edge.x1,y1,x2,y2`)

---

## 4) Render it your way

The core doesn’t draw. Iterate and paint using your engine.

```lua
-- Edges first so nodes appear on top
for e in NM.edges(graph) do
  drawLine(e.x1, e.y1, e.x2, e.y2, e.color)   -- thickness/style is yours
end

-- Nodes
for n in NM.nodes(graph) do
  local s = 1.0
  if n.can_be_visited and not n.visited then
    -- optional pulse: 10% scale oscillation
    s = 1.0 + 0.1 * math.sin(n.pulse_phase)
  end
  drawCircle(n.x, n.y, n.rs * s, n.color, n.hot and n.can_be_visited)

  if n.label then
    -- offset label away from neighbor centroid
    local r = n.label_r
    local dx, dy = math.cos(r), math.sin(r)
    drawText(n.label, n.x + dx * (n.rs * 3), n.y + dy * (n.rs * 3), n.label_color)
  end
end
```

> Tip: If you have screen-space UI, convert world→screen before drawing text.

---

## 5) Minimal LÖVE example (drop-in)

A tiny LÖVE scene that wires everything together.

```lua
-- main.lua
local NM = require 'nodemap_core_headless'
local graph

function love.load()
  love.window.setMode(800, 600)
  local map = {
    [1] = {x=400,y=300,links={2,3,4,5}, visited=true, label='Start'},
    [2] = {x=400,y=220,links={1}, label='North'},
    [3] = {x=480,y=300,links={1}, label='East'},
    [4] = {x=400,y=380,links={1}, label='South'},
    [5] = {x=320,y=300,links={1}, label='West'},
  }
  graph = NM.generate(map, {color_mode='skill_tree'})
end

local click = false
function love.mousepressed(_,_,button)
  if button == 1 then click = true end
end

function love.update(dt)
  local mx, my = love.mouse.getX(), love.mouse.getY()
  NM.update(graph, dt, { mx = mx, my = my, m1_pressed = click })
  click = false
end

local function setColor(c)
  love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
end

function love.draw()
  love.graphics.clear(0.08,0.08,0.08,1)
  -- edges
  for e in NM.edges(graph) do
    setColor(e.color)
    love.graphics.setLineWidth(3)
    love.graphics.line(e.x1, e.y1, e.x2, e.y2)
  end
  -- nodes
  for n in NM.nodes(graph) do
    local s = 1.0
    if n.can_be_visited and not n.visited then s = 1.0 + 0.1*math.sin(n.pulse_phase) end
    setColor(n.color)
    love.graphics.circle('fill', n.x, n.y, n.rs * s)
    -- outline
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0,0,0,0.15)
    love.graphics.circle('line', n.x, n.y, n.rs * s)
    -- label
    if n.label then
      local r = n.label_r
      local dx, dy = math.cos(r), math.sin(r)
      setColor(n.label_color)
      love.graphics.print(n.label, n.x + dx*(n.rs*3), n.y + dy*(n.rs*3))
    end
  end
end
```

---

## 6) Advanced patterns

### Seed multiple entry points

```lua
nodemap[10].visited = true       -- hub A
nodemap[42].visited = true       -- hub B
```

Both hubs will radiate visitability to their neighbors after the first update.

### Lock gating with custom rules

You can inject your own rule in your game loop before calling `NM.update`:

```lua
-- Example: require player level >= 5 to visit node 7
local n = graph.nodes[7]
if n then
  n.can_be_visited = n.can_be_visited and (player.level >= 5)
end
```

### Manual visit / reset

```lua
graph.nodes[3].visited = true
-- clear state
for n in NM.nodes(graph) do n.visited, n.can_be_visited = false, false end
```

### Serialization (save/load)

Only persist what you need (id → visited/can\_be\_visited):

```lua
local save = {}
for n in NM.nodes(graph) do save[n.id] = { visited=n.visited, can=n.can_be_visited } end
-- later
for id,state in pairs(save) do
  if graph.nodes[id] then
    graph.nodes[id].visited = state.visited
    graph.nodes[id].can_be_visited = state.can
  end
end
```

### Custom color policy

Ignore built-in palette and assign colors in your renderer:

```lua
local function nodeColor(n)
  if n.visited then return {0.9,0.9,0.9,1}
  elseif n.can_be_visited then return {1,1,1,1}
  else return {0.3,0.3,0.3,1} end
end
```

---

## 7) Field reference (runtime)

**Node**

* `id, x, y, rs`
* `neighbors` (array of ids)
* `visited, can_be_visited, hot`
* `color_mode`
* `src_color, color, label_color` (suggestive — optional for you to use)
* `label, label_r`
* `pulse_phase` (animate scale if desired)
* `data` (your payload)
* `on_visit(node)` (callback)

**Edge**

* `n1, n2` (node refs)
* `x1,y1,x2,y2` (rim-adjusted endpoints)
* `color_mode, color`

---

## 8) Troubleshooting

* **Nothing becomes visitable** → Make sure at least one node starts `visited=true` *or* you seed `can_be_visited=true` on entry nodes.
* **Hover never triggers** → Check your `mx,my` are in the same coordinate space as your node positions; radius check is `<= 1.5 * rs`.
* **Click doesn’t register** → `m1_pressed` must be edge-triggered (true *only* on the frame the button went down).
* **Labels overlap** → Increase offset multiplier from `n.rs*3` to `n.rs*4..6` in your renderer, or add small per-node `label_dx, label_dy` in `data` and apply them.

---

## 9) Extending the core (optional)

* Add keyboard/gamepad selection: keep `graph.cursor = nodeId` and synthesize `hot`/click based on focus.
* Path preview: when hovering a node, draw a subtle line to all `visited` neighbors to communicate reachable paths.
* Weighted edges: store cost on nodemap entries (e.g., `{links={ {2, cost=3}, 3, 4 }}`) and adapt generator.

---

That’s it — plug in your renderer and you’re live. If you want, I can add a ready-to-run raylib or LÖVE demo that mirrors your project style.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
