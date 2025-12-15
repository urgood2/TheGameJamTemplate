--[[
 nodemap_core_headless.lua — minimal, renderer-agnostic nodemap core
 ─────────────────────────────────────────────────────────────────────────────
 • No Object:extend / GameObject mixins
 • No timers/tweens; no graphics calls
 • Update-only logic (hover, click, visitability, label orientation)
 • Your renderer supplies draw logic; this file returns pure state

 QUICK START
 -----------------------------------------------------------------------------
 local NM = require 'nodemap_core_headless'
 local map = {
   [1] = {x=400,y=300,links={2,3,4,5}, visited=true, color={1,0.9,0.2,1}, label='Start'},
   [2] = {x=400,y=220,links={1}, label='Top'},
   [3] = {x=480,y=300,links={1}, label='Right'},
   [4] = {x=400,y=380,links={1}, label='Bottom'},
   [5] = {x=320,y=300,links={1}, label='Left'},
 }
 local graph = NM.generate(map, {color_mode='skill_tree'})
 
 -- per-frame
 NM.update(graph, dt, {mx=mouseX, my=mouseY, m1_pressed=mousePressedEdge})
 
 -- rendering (pseudo):
 for _,e in NM.edges(graph) do
   -- draw a line from e.x1,e.y1 to e.x2,e.y2 using e.color/state
 end
 for _,n in NM.nodes(graph) do
   -- draw a circle at n.x,n.y with radius n.rs and color n.color
   -- if n.hot and n.can_be_visited, you might draw a filled circle
   -- if n.label, draw it using n.label_r for offset direction
   -- optional scale pulse: s = 1 + 0.1*math.sin(n.pulse_phase)
 end

 DESIGN NOTES
 -----------------------------------------------------------------------------
 • "skill_tree" color mode mirrors your original: unvisitable=gray, visitable=white,
   visited=node.src_color. Default mode keeps provided color; visited becomes gray.
 • We expose color values but you can ignore them and use your own theme.
 • We keep a per-node pulse_phase you can animate for visitable nodes.
 • All input is injected via NM.update(graph, dt, input).

 MIT License.
]]

local NM = {}

-- math helpers
local function dist(ax,ay,bx,by) local dx,dy=bx-ax,by-ay; return (dx*dx+dy*dy)^0.5 end
local function angle(ax,ay,bx,by) return math.atan(by-ay, bx-ax) end  -- Lua 5.4 compat

-- default palette (used if you rely on NM-managed colors)
NM.palette = {
  bg_dim     = {0.23,0.23,0.23,1.0},
  bg_mid     = {0.35,0.35,0.35,1.0},
  bg_bright  = {0.55,0.55,0.55,1.0},
  fg         = {0.86,0.86,0.86,1.0},
}

-- iterators
function NM.nodes(graph)
  return coroutine.wrap(function()
    for _,n in pairs(graph.nodes) do coroutine.yield(n) end
  end)
end
function NM.edges(graph)
  return coroutine.wrap(function()
    for _,e in pairs(graph.edges) do coroutine.yield(e) end
  end)
end

-- internal utilities
local function copy_color(c) return c and {c[1],c[2],c[3],c[4] or 1} or nil end

-- build graph (nodes, then edges, then late-bind)
function NM.generate(nodemap, opts)
  opts = opts or {}
  local g = { nodes = {}, edges = {}, opts = opts }
  if opts.palette then NM.palette = opts.palette end

  -- nodes
  for id, node in pairs(nodemap) do
    local n = {
      id = id,
      x = assert(node.x), y = assert(node.y),
      rs = node.rs or 6,
      neighbors = node.links or node.neighbors or {},
      label = node.label,
      visited = not not node.visited,
      can_be_visited = not not node.can_be_visited,
      color_mode = opts.color_mode,
      src_color = copy_color(node.color) or copy_color(NM.palette.fg),
      color = copy_color(node.color) or copy_color(NM.palette.fg),
      label_color = copy_color(node.color) or copy_color(NM.palette.fg),
      label_r = 0,
      hot = false,
      pulse_phase = 0, -- consumer can animate scale using this
      data = node.data or {},
      on_visit = node.on_visit,
      on_draw = node.on_draw, -- ignored here; provided for your renderer
    }

    -- color mode initialization
    if n.color_mode == 'skill_tree' then
      n.color = copy_color(NM.palette.bg_mid)
      if n.visited then n.color = copy_color(NM.palette.fg) end
      n.label_color = copy_color(n.color)
    end

    g.nodes[id] = n
  end

  -- edges (avoid duplicates by ordering id string)
  local made = {}
  local function key(a,b) if tostring(a) < tostring(b) then return tostring(a)..'>'..tostring(b) else return tostring(b)..'>'..tostring(a) end end
  for id, node in pairs(nodemap) do
    local links = node.links or node.neighbors or {}
    for _, nid in ipairs(links) do
      if nodemap[nid] then
        local k = key(id, nid)
        if not made[k] then
          local e = { node1_id=id, node2_id=nid, color_mode=opts.color_mode, color=copy_color(NM.palette.fg) }
          -- resolve node refs
          e.n1 = g.nodes[id]; e.n2 = g.nodes[nid]
          -- endpoints offset by node radii
          local r = angle(e.n1.x, e.n1.y, e.n2.x, e.n2.y)
          e.x1 = e.n1.x + 2.75*e.n1.rs*math.cos(r)
          e.y1 = e.n1.y + 2.75*e.n1.rs*math.sin(r)
          e.x2 = e.n2.x + 2.75*e.n2.rs*math.cos(r - math.pi)
          e.y2 = e.n2.y + 2.75*e.n2.rs*math.sin(r - math.pi)
          if e.color_mode == 'skill_tree' then e.color = copy_color(NM.palette.bg_mid) end
          table.insert(g.edges, e)
          made[k] = true
        end
      end
    end
  end

  -- late-bind: label orientation away from neighbor centroid
  for _,n in pairs(g.nodes) do
    if n.label and n.neighbors then
      local xs, ys = 0, 0
      for _, nid in ipairs(n.neighbors) do
        local nb = g.nodes[nid]
        if nb then local r = angle(n.x, n.y, nb.x, nb.y); xs = xs + math.cos(r); ys = ys + math.sin(r) end
      end
      n.label_r = math.atan(-ys, -xs)  -- Lua 5.4 compat
    end
  end

  return g
end

-- Update hover, click/visit, visitability propagation, edge colors
-- input = {mx, my, m1_pressed}
function NM.update(graph, dt, input)
  input = input or {mx=0,my=0,m1_pressed=false}
  local mx, my, m1 = input.mx or 0, input.my or 0, not not input.m1_pressed

  -- node pass
  for _,n in pairs(graph.nodes) do
    local was_hot = n.hot
    n.hot = (dist(n.x, n.y, mx, my) <= 1.5*n.rs)

    -- propagate visitability if any neighbor visited
    if not n.visited and not n.can_be_visited then
      for _, nid in ipairs(n.neighbors or {}) do
        local nb = graph.nodes[nid]
        if nb and nb.visited then n.can_be_visited = true; break end
      end
    end

    -- color affordances in skill_tree mode
    if n.color_mode == 'skill_tree' then
      if n.can_be_visited and not n.visited then
        n.color = copy_color(NM.palette.bg_bright)
        n.label_color = copy_color(n.color)
        if n.hot then n.color = copy_color(NM.palette.fg); n.label_color = copy_color(n.color) end
      elseif n.visited then
        n.color = copy_color(n.src_color)
        n.label_color = copy_color(n.color)
      else
        n.color = copy_color(NM.palette.bg_mid)
        n.label_color = copy_color(n.color)
      end
    else
      if n.visited then n.color = copy_color(NM.palette.bg_mid) else n.color = copy_color(n.src_color) end
      n.label_color = copy_color(n.color)
    end

    -- simple pulse when visitable
    if n.can_be_visited and not n.visited then n.pulse_phase = (n.pulse_phase + (dt*2.0)) % (2*math.pi) end

    -- click-to-visit
    if m1 and n.hot and n.can_be_visited and not n.visited then
      n.can_be_visited = false
      n.visited = true
      -- set final colors
      if n.color_mode == 'skill_tree' then
        n.color = copy_color(n.src_color)
        n.label_color = copy_color(n.src_color)
      else
        n.color = copy_color(NM.palette.bg_mid)
        n.label_color = copy_color(n.color)
      end
      if n.on_visit then n.on_visit(n) end
    end

    -- NOTE: If you need hover enter/exit callbacks, you can track was_hot→n.hot
    -- transitions here and call your own hooks.
  end

  -- edge pass: recolor & refresh endpoints
  for _,e in ipairs(graph.edges) do
    local n1, n2 = e.n1, e.n2
    if e.color_mode == 'skill_tree' then
      -- default dim
      e.color = copy_color(NM.palette.bg_mid)
      -- if connects visited → visitable (but not yet visited), brighten
      if (n1.visited and n2.can_be_visited and not n2.visited) or
         (n2.visited and n1.can_be_visited and not n1.visited) then
        e.color = copy_color(NM.palette.bg_bright)
      end
      -- if both visited or hovered next to visited, set to fg
      if (n1.visited and n2.visited) or (n1.visited and n2.hot) or (n2.visited and n1.hot) then
        e.color = copy_color(NM.palette.fg)
      end
    else
      if n1.visited and n2.visited then e.color = copy_color(NM.palette.bg_mid) else e.color = copy_color(NM.palette.fg) end
    end

    local r = angle(n1.x, n1.y, n2.x, n2.y)
    e.x1 = n1.x + 2.75*n1.rs*math.cos(r)
    e.y1 = n1.y + 2.75*n1.rs*math.sin(r)
    e.x2 = n2.x + 2.75*n2.rs*math.cos(r - math.pi)
    e.y2 = n2.y + 2.75*n2.rs*math.sin(r - math.pi)
  end
end

return NM
