-- Command-buffer friendly rich text renderer.
-- Merges the character-effect mixin with the existing command_buffer + behavior_script_v2 flow.
--
-- Usage:
--   local Text = require("ui.command_buffer_text")
--   local t = Text({
--     text = "[Hello](color=Col(255,0,0)) world",
--     w = 240,
--     x = 320, y = 180,
--     layer = layers.ui,
--     z = 10,
--   })
--   -- If attached as a MonoBehaviour, update_all() will call :update(dt) automatically.
--   -- Otherwise, call t:update(dt) yourself each frame.
--
-- ===============================================================================
-- PERFORMANCE CHARACTERISTICS:
-- ===============================================================================
-- This renderer issues command buffer calls PER CHARACTER each frame.
--
-- Rendering Cost Breakdown:
-- - Characters WITHOUT scale effects: 1 queueTextPro call per character
-- - Characters WITH scale effects:    5 command buffer calls per character
--   (queuePushMatrix, queueTranslate, queueScale, queueTextPro, queuePopMatrix)
--
-- Example Impact:
-- - 100 characters with scale effects = 500 command buffer calls per frame
-- - At 60 FPS, this is 30,000 command buffer calls per second
--
-- Profiling Recommendations:
-- - Use Tracy zones (if available) to measure render time: tracy.ZoneBegin/End
-- - Monitor command buffer queue length via command_buffer internals
-- - Test with realistic text loads (50-200 characters with mixed effects)
--
-- Optimization Strategies (if performance issues arise):
-- 1. Character batching: Group consecutive characters with identical transforms
-- 2. Instanced rendering: Use a single draw call for all characters
-- 3. Effect budgeting: Limit scale effects to N characters per text object
-- 4. Culling: Skip effects for off-screen or alpha=0 characters
-- 5. Object pooling: Reuse Col objects instead of creating new ones each frame
--
-- Current Bottlenecks:
-- - Matrix operations are NOT batched (each character gets its own matrix stack)
-- - Color objects are allocated every frame (creates GC pressure)
-- - No spatial culling (all characters render even if off-screen)
--
-- ===============================================================================

local Node = require("monobehavior.behavior_script_v2")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local text_effects = require("ui.text_effects")
-- Load all effect modules
require("ui.text_effects.static")
require("ui.text_effects.continuous")
require("ui.text_effects.oneshot")
require("ui.text_effects.juicy")
require("ui.text_effects.magical")
require("ui.text_effects.elemental")

local CommandBufferText = Node:extend()

local unpack = table.unpack or unpack

local DEFAULT_LINE_HEIGHT = 1.1
local DEFAULT_COLOR = (Col and Col(255, 255, 255, 255)) or { r = 255, g = 255, b = 255, a = 255 }

local function get_time()
  if main_loop and main_loop.getTime then
    return main_loop.getTime()
  end
  return os.clock()
end

local function measure_width(str, font_size, spacing)
  if localization and localization.getTextWidthWithCurrentFont then
    local ok, w = pcall(localization.getTextWidthWithCurrentFont, str, font_size, spacing or 1)
    if ok and w then return w end
  end
  -- Fallback heuristic for tests/headless runs.
  return (#str) * (font_size * 0.55)
end

local function parse_effect_arg(raw)
  raw = tostring(raw or "")
  if raw == "" then return raw end
  if raw:find("#") then return raw end

  -- Try to evaluate as Lua literal (number, boolean, etc.)
  local chunk = load("return " .. raw)
  if not chunk then return raw end
  local ok, val = pcall(chunk)

  -- If evaluation failed, or returned nil, keep the original string
  -- This allows color names like "red", "gold", etc. to pass through as strings
  if not ok or val == nil then
    return raw
  end

  return val
end

local function parse_effects(effect_str)
  local parsed = {}
  for effect in string.gmatch(effect_str or "", "[^;]+") do
    local name, args = effect:match("^%s*([^=]+)%s*=%s*(.+)%s*$")
    name = name or effect:match("^%s*(.-)%s*$")
    if name and name ~= "" then
      local entry = { name }
      if args then
        for arg in string.gmatch(args, "[^,]+") do
          table.insert(entry, parse_effect_arg(arg))
        end
      end
      table.insert(parsed, entry)
    end
  end
  return parsed
end

local DEFAULT_EFFECTS = {
  color = function(_, _, char, color)
    char.color = color
  end,
  shake = function(_, dt, char, intensity, duration)
    local amp = tonumber(intensity) or 1
    local dur = tonumber(duration) or 0

    if dur > 0 then
      char._shake_t = (char._shake_t or 0) + dt
      if char._shake_t > dur then
        return
      end
    end

    local decay = 1
    if dur > 0 and char._shake_t then
      decay = math.max(0, (dur - char._shake_t) / dur)
    end

    local range = amp * decay
    char.ox = (char.ox or 0) + (math.random() * 2 - 1) * range
    char.oy = (char.oy or 0) + (math.random() * 2 - 1) * range
  end
}

local function merge_effects(custom)
  local merged = {}
  for k, v in pairs(DEFAULT_EFFECTS) do merged[k] = v end
  for k, v in pairs(custom or {}) do merged[k] = v end
  return merged
end

function CommandBufferText:init(args)
  CommandBufferText.super.init(self, args)
  args = args or {}

  self.raw_text = args.text or args.raw_text or ""
  self.w = args.w or args.width
  assert(self.w, "command_buffer_text requires a wrap width (w)")

  self.x = args.x or 0
  self.y = args.y or 0
  self.offset_x = args.offset_x or 0
  self.offset_y = args.offset_y or 0
  self.z = args.z or args.z_index or 0

  self.layer = args.layer or (layers and layers.ui) or (_G.layers and _G.layers.ui)
  -- Default to Screen space if not specified; try multiple fallback sources
  self.render_space = args.render_space or args.space
      or (self.layer and self.layer.DrawCommandSpace and self.layer.DrawCommandSpace.Screen)
      or (layer and layer.DrawCommandSpace and layer.DrawCommandSpace.Screen)
      or (_G.layer and _G.layer.DrawCommandSpace and _G.layer.DrawCommandSpace.Screen)

  self.font = args.font or (localization and localization.getFont and localization.getFont())
  self.font_size = args.font_size or args.fontSize or 16

  -- Base transform for whole-text animations (pop, bounce, etc.)
  self.base_scale = args.base_scale or 1
  self.base_rotation = args.base_rotation or 0
  self.alignment = args.text_alignment or args.alignment or "left"
  self.anchor = args.anchor or "center"  -- "center" or "topleft"
  self.height_multiplier = args.height_multiplier or args.line_height or DEFAULT_LINE_HEIGHT
  self.letter_spacing = args.spacing or args.letter_spacing or 1
  local base_color = args.color
  if type(base_color) == "string" then
    base_color = text_effects.get_color(string.lower(base_color))
  end
  self.base_color = base_color or DEFAULT_COLOR
  self.follow_transform = args.follow_transform ~= false

  self.text_effects = merge_effects(args.text_effects)

  self.default_effects = nil
  local default_effects = args.effects or args.default_effects
  if default_effects then
    if type(default_effects) == "string" then
      self.default_effects = parse_effects(default_effects)
    elseif type(default_effects) == "table" then
      self.default_effects = default_effects
    end
  end

  -- Shader entity for rendering through shader pipeline
  -- When set, uses shader_draw_commands.add_local_command instead of command_buffer.queueTextPro
  self.shader_entity = args.shader_entity

  self.characters = {}
  self.text_w = 0
  self.text_h = self.font_size * self.height_multiplier
  self.first_frame = true
  self.dirty = true

  self:rebuild()
end

function CommandBufferText:rebuild(new_text)
  if new_text ~= nil then
    self.raw_text = new_text
  end
  self.characters = self:_parse_text(self.raw_text or "")
  self:_format_characters()
  self.dirty = false
  self.first_frame = true
end

function CommandBufferText:set_text(new_text)
  self.raw_text = new_text or ""
  self.dirty = true
end

function CommandBufferText:set_width(w)
  if w and w ~= self.w then
    self.w = w
    self.dirty = true
  end
end

--- Set base scale for whole-text animations (multiplies with per-character scale)
--- @param s number Scale value (1 = normal, 0 = invisible)
function CommandBufferText:set_base_scale(s)
  self.base_scale = s or 1
end

--- Set base rotation for whole-text animations (adds to per-character rotation)
--- @param r number Rotation in degrees
function CommandBufferText:set_base_rotation(r)
  self.base_rotation = r or 0
end

function CommandBufferText:_parse_text(raw)
  local parsed_segments = {}
  for i, field, j, effects, k in string.gmatch(raw, "()%[(.-)%]()%((.-)%)()") do
    local parsed_effects = parse_effects(effects)
    table.insert(parsed_segments, {
      i = tonumber(i),
      j = tonumber(j),
      k = tonumber(k),
      field = field,
      effects = parsed_effects
    })
  end

  local characters = {}
  for idx = 1, #raw do
    local ch = raw:sub(idx, idx)
    local effects = nil
    local include = true

    for _, seg in ipairs(parsed_segments) do
      if idx >= seg.i + 1 and idx <= seg.j - 2 then
        effects = seg.effects
      end
      if (idx >= seg.j and idx <= seg.k - 1) or idx == seg.i or idx == seg.j - 1 then
        include = false
        break
      end
    end

    if include then
      local combined_effects = {}
      if self.default_effects and #self.default_effects > 0 then
        for _, eff in ipairs(self.default_effects) do
          table.insert(combined_effects, eff)
        end
      end
      if effects and #effects > 0 then
        for _, eff in ipairs(effects) do
          table.insert(combined_effects, eff)
        end
      end
      table.insert(characters, { c = ch, effects = combined_effects })
    end
  end

  return characters
end

function CommandBufferText:_format_characters()
  local chars = self.characters or {}
  local line_height = self.font_size * self.height_multiplier
  local cx, cy, line = 0, 0, 1
  local space_w = measure_width(" ", self.font_size, self.letter_spacing)

  for idx, ch in ipairs(chars) do
    local char = ch.c
    if char == "|" or char == "\n" then
      cx = 0
      cy = cy + line_height
      line = line + 1
      ch._remove = true
    elseif char == " " then
      local word_w = 0
      local j = idx + 1
      while j <= #chars do
        local c2 = chars[j].c
        if c2 == " " or c2 == "|" or c2 == "\n" then break end
        word_w = word_w + measure_width(c2, self.font_size, self.letter_spacing)
        j = j + 1
      end

      if cx + space_w + word_w > self.w then
        cx = 0
        cy = cy + line_height
        line = line + 1
        ch._remove = true
      else
        ch.x, ch.y, ch.line = cx, cy, line
        ch.r = 0
        ch.ox, ch.oy = 0, 0
        ch.w, ch.h = space_w, line_height
        -- NEW: Extended properties
        ch.rotation = 0
        ch.scale = 1
        ch.scaleX = 1
        ch.scaleY = 1
        ch.alpha = 255
        ch.codepoint = nil
        ch.effect_data = {}
        ch.effect_finished = nil
        cx = cx + space_w
      end
    else
      local w = measure_width(char, self.font_size, self.letter_spacing)
      ch.x, ch.y, ch.line = cx, cy, line
      ch.r = 0
      ch.ox, ch.oy = 0, 0
      ch.w, ch.h = w, line_height
      -- NEW: Extended properties
      ch.rotation = 0
      ch.scale = 1
      ch.scaleX = 1
      ch.scaleY = 1
      ch.alpha = 255
      ch.codepoint = nil
      ch.effect_data = {}
      ch.effect_finished = nil
      cx = cx + w
      if cx > self.w then
        cx = 0
        cy = cy + line_height
        line = line + 1
      end
    end
  end

  for i = #chars, 1, -1 do
    if chars[i]._remove then table.remove(chars, i) end
  end

  for i, ch in ipairs(chars) do
    ch.i = i
  end

  local line_widths = {}
  local max_line = 0
  local max_w = 0

  for _, ch in ipairs(chars) do
    local ln = ch.line or 1
    line_widths[ln] = (line_widths[ln] or 0) + (ch.w or 0)
    if ln > max_line then max_line = ln end
  end

  for _, w in pairs(line_widths) do
    if w > max_w then max_w = w end
  end

  if max_line == 0 then
    self.text_w = 0
    self.text_h = line_height
    return
  end

  self.text_w = max_w
  self.text_h = (max_line - 1) * line_height + line_height

  local align = self.alignment
  if align == "justified" then align = "justify" end

  if align ~= "left" then
    for ln = 1, max_line do
      local lw = line_widths[ln] or 0
      local leftover = max_w - lw
      if align == "center" then
        local offset = leftover * 0.5
        for _, ch in ipairs(chars) do
          if ch.line == ln then
            ch.x = ch.x + offset
          end
        end
      elseif align == "right" then
        for _, ch in ipairs(chars) do
          if ch.line == ln then
            ch.x = ch.x + leftover
          end
        end
      elseif align == "justify" and lw > 0 then
        local spaces = 0
        for _, ch in ipairs(chars) do
          if ch.line == ln and ch.c == " " then
            spaces = spaces + 1
          end
        end
        if spaces > 0 then
          local extra = leftover / spaces
          local added = 0
          for _, ch in ipairs(chars) do
            if ch.line == ln then
              if ch.c == " " then
                ch.x = ch.x + added
                added = added + extra
              else
                ch.x = ch.x + added
              end
            end
          end
        end
      end
    end
  end
end

function CommandBufferText:update(dt)
  -- =========================================================================
  -- PERFORMANCE PROFILING HOOK POINT
  -- =========================================================================
  -- To profile this function's performance, wrap it with Tracy zones:
  --
  --   if tracy then tracy.ZoneBeginN("TextEffectsUpdate") end
  --   -- ... update logic ...
  --   if tracy then tracy.ZoneEnd() end
  --
  -- Or use manual timing for platforms without Tracy:
  --
  --   local start_time = os.clock()
  --   -- ... update logic ...
  --   local elapsed = os.clock() - start_time
  --   if elapsed > 0.002 then  -- Log if > 2ms
  --     print(string.format("CommandBufferText slow frame: %.3fms", elapsed * 1000))
  --   end
  --
  -- Metrics to track:
  --   - Total update time (should be < 1-2ms for 100 characters)
  --   - Command buffer calls issued (count queueTextPro calls)
  --   - Matrix push/pop count (equals scaled character count)
  --   - GC allocations (monitor Col object creation)
  -- =========================================================================

  if self.dirty then
    self:rebuild()
  end

  local layer_handle = self.layer or (layers and layers.ui)
  if not (command_buffer and command_buffer.queueDrawText and layer_handle) then
    return
  end

  local base_x = self.x or 0
  local base_y = self.y or 0
  if self.follow_transform and self._eid then
    local t = component_cache.get(self._eid, Transform)
    if t then
      base_x = t.actualX or t.x or base_x
      base_y = t.actualY or t.y or base_y
    end
  end
  base_x = base_x + (self.offset_x or 0)
  base_y = base_y + (self.offset_y or 0)

  local anchor_center = not (self.anchor == "topleft" or self.anchor == "top-left" or self.anchor == "top")
  local origin_x = anchor_center and (base_x - self.text_w * 0.5) or base_x
  local origin_y = anchor_center and (base_y - self.text_h * 0.5) or base_y

  -- Update shader entity's Transform to match text bounding box
  -- Local commands render relative to entity position, so entity must be at text's top-left
  if self.shader_entity and entity_cache.valid(self.shader_entity) then
    local t = component_cache.get(self.shader_entity, Transform)
    if t then
      -- Position entity at text's top-left corner (not anchor point)
      t.actualX = origin_x
      t.actualY = origin_y
      -- Size entity to encompass all text (local commands must be within entity bounds)
      t.actualW = math.max(self.text_w, 1)
      t.actualH = math.max(self.text_h, 1)
    end
  end

  local font_ref = self.font or (localization and localization.getFont and localization.getFont())
  local default_color = self.base_color

  -- Check if we should render through shader pipeline (used both in loop and after)
  local use_shader_pipeline = self.shader_entity and
      entity_cache.valid(self.shader_entity) and
      shader_draw_commands and shader_draw_commands.add_local_command

  -- Debug: Log shader pipeline check (once per instance)
  if self.shader_entity and not self._shader_check_logged then
    self._shader_check_logged = true
    local valid = entity_cache.valid(self.shader_entity)
    local has_sdc = shader_draw_commands and shader_draw_commands.add_local_command
    print(string.format("[CBT] Shader check: entity=%s valid=%s has_sdc=%s use_pipeline=%s",
      tostring(self.shader_entity), tostring(valid), tostring(has_sdc), tostring(use_shader_pipeline)))
  end

  for _, ch in ipairs(self.characters) do
    -- Reset per-frame properties
    ch.ox, ch.oy = 0, 0
    ch.rotation = 0
    ch.scale = 1
    ch.scaleX = 1
    ch.scaleY = 1
    ch.alpha = 255
    ch.color = nil
    -- Don't reset: ch.effect_data (persistent), ch.codepoint, ch.created_at

    if ch.effects and #ch.effects > 0 then
      -- Build context for effects
      local ctx = {
        time = get_time(),
        char_count = #self.characters,
        text_w = self.text_w,
        text_h = self.text_h,
        first_frame = self.first_frame,
      }

      for _, eff in ipairs(ch.effects) do
        local name = eff[1]
        -- Try registry first, then custom effects
        local registered = text_effects.get(name)
        if registered then
          local args = {}
          for i = 2, #eff do args[i-1] = eff[i] end
          text_effects.apply(name, ctx, dt, ch, args)
        else
          local fn = name and self.text_effects[name]
          if fn then
            fn(self, dt or 0, ch, unpack(eff, 2))
          else
            -- Warn once per unknown effect
            if not self._warned_effects then self._warned_effects = {} end
            if not self._warned_effects[name] then
              print("Warning: Unknown text effect '" .. tostring(name) .. "'")
              self._warned_effects[name] = true
            end
          end
        end
      end
    end

    local draw_x = origin_x + (ch.x or 0) + (ch.ox or 0)
    local draw_y = origin_y + (ch.y or 0) + (ch.oy or 0)
    local draw_char = ch.codepoint or ch.c
    -- Apply base transforms (for whole-text animations) + per-character transforms
    local draw_rotation = (ch.rotation or 0) + (self.base_rotation or 0)
    local draw_scale = (ch.scale or 1) * (self.base_scale or 1)
    local draw_scaleX = draw_scale * (ch.scaleX or 1)
    local draw_scaleY = draw_scale * (ch.scaleY or 1)
    local draw_color = ch.color or default_color
    -- Always convert to proper Col userdata to ensure C++ compatibility
    -- Effects may return plain tables, but command buffer expects Color userdata
    local alpha = (ch.alpha and ch.alpha < 255) and ch.alpha or (draw_color.a or 255)
    if draw_color.r and draw_color.g and draw_color.b then
      draw_color = Col(draw_color.r, draw_color.g, draw_color.b, alpha)
    end

    local needs_scale = draw_scaleX ~= 1 or draw_scaleY ~= 1
    local char_z = self.z or 0

    -- Calculate character center for proper rotation pivot
    -- Raylib's DrawTextPro uses origin as both rotation center AND anchor point
    local char_w = ch.w or self.font_size * 0.6
    local char_h = ch.h or self.font_size
    local center_x = char_w * 0.5
    local center_y = char_h * 0.5

    if use_shader_pipeline then
      -- =====================================================================
      -- SHADER PIPELINE PATH
      -- =====================================================================
      -- Routes draw commands through entity's ShaderPipelineComponent.
      -- This enables per-text shader effects like polychrome, dissolve, etc.
      --
      -- IMPORTANT: Local commands render relative to entity's Transform position.
      -- Entity is positioned at origin_x/origin_y (text's top-left corner).
      -- Since draw_x = origin_x + ch.x + ch.ox, local coords = ch.x + ch.ox + center_x
      -- =====================================================================
      local local_x = (ch.x or 0) + (ch.ox or 0) + center_x
      local local_y = (ch.y or 0) + (ch.oy or 0) + center_y

      -- Debug log (only once)
      if not self._shader_debug_logged then
        self._shader_debug_logged = true
        print(string.format("[CBT SHADER] entity=%s, entity_pos=(%.1f,%.1f), entity_size=(%.1f,%.1f), first_char_local=(%.1f,%.1f)",
          tostring(self.shader_entity), origin_x, origin_y, self.text_w, self.text_h, local_x, local_y))
      end

      -- Create origin with fallback (matching gameplay.lua pattern)
      local origin = (_G.Vector2 and _G.Vector2(center_x, center_y)) or { x = center_x, y = center_y }

      shader_draw_commands.add_local_command(
        registry,
        self.shader_entity,
        "text_pro",
        function(c)
          c.text = draw_char
          c.font = font_ref
          c.x = local_x
          c.y = local_y
          c.origin = origin
          c.rotation = draw_rotation
          c.fontSize = self.font_size
          c.spacing = self.letter_spacing or 1
          c.color = draw_color
        end,
        char_z,
        _G.layer.DrawCommandSpace.World, -- Local commands use world space relative to entity
        true   -- textPass: enable text pass rendering
      )
    elseif needs_scale then
      -- =====================================================================
      -- PERFORMANCE WARNING: Matrix Transform Path
      -- =====================================================================
      -- This path uses 5 command buffer calls per character to support scale.
      -- This is required because Raylib's DrawTextPro doesn't support scale.
      --
      -- Cost per scaled character:
      --   1. queuePushMatrix    - Save matrix state
      --   2. queueTranslate     - Move to character position
      --   3. queueScale         - Apply scale transform
      --   4. queueTextPro       - Draw character at origin
      --   5. queuePopMatrix     - Restore matrix state
      --
      -- Impact: For 50 characters with scale effects:
      --   - 250 command buffer calls per frame
      --   - Increased CPU time for matrix stack operations
      --   - Potential batching breaks in the render pipeline
      --
      -- Optimization Opportunity:
      --   - Batch consecutive characters with identical scale values
      --   - Use a custom shader that supports per-character scale
      --   - Render scaled text to texture once, then composite
      -- =====================================================================
      command_buffer.queuePushMatrix(layer_handle, function(c) end, char_z, self.render_space)
      command_buffer.queueTranslate(layer_handle, function(c)
        -- Translate to character center for proper rotation
        c.x = draw_x + center_x
        c.y = draw_y + center_y
      end, char_z, self.render_space)
      command_buffer.queueScale(layer_handle, function(c)
        c.x = draw_scaleX
        c.y = draw_scaleY
      end, char_z, self.render_space)
      command_buffer.queueTextPro(layer_handle, function(c)
        c.text = draw_char
        c.font = font_ref
        c.x = 0
        c.y = 0
        -- Origin at center so rotation pivots around character center
        c.origin = (_G.Vector2 and _G.Vector2(center_x, center_y)) or { x = center_x, y = center_y }
        c.rotation = draw_rotation
        c.fontSize = self.font_size
        c.spacing = self.letter_spacing or 1
        c.color = draw_color
      end, char_z, self.render_space)
      command_buffer.queuePopMatrix(layer_handle, function(c) end, char_z, self.render_space)
    else
      -- Fast path: Single command buffer call for unscaled characters
      -- This path should be used whenever possible for best performance
      -- DEBUG: Log non-white colors once per text instance
      if draw_color and draw_color.r and (draw_color.r ~= 255 or draw_color.g ~= 255 or draw_color.b ~= 255) then
        if not self._logged_color then
          self._logged_color = true
          print(string.format("[CBT DEBUG] Non-white color detected: r=%d g=%d b=%d a=%d for char '%s'",
            draw_color.r or 0, draw_color.g or 0, draw_color.b or 0, draw_color.a or 0, draw_char or "?"))
        end
      end
      command_buffer.queueTextPro(layer_handle, function(c)
        c.text = draw_char
        c.font = font_ref
        -- Position at character center for proper rotation pivot
        c.x = draw_x + center_x
        c.y = draw_y + center_y
        -- Origin at center so rotation pivots around character center
        c.origin = (_G.Vector2 and _G.Vector2(center_x, center_y)) or { x = center_x, y = center_y }
        c.rotation = draw_rotation
        c.fontSize = self.font_size
        c.spacing = self.letter_spacing or 1
        c.color = draw_color
      end, char_z, self.render_space)
    end
  end

  if self.first_frame then self.first_frame = false end

  -- =========================================================================
  -- SHADER PIPELINE EXECUTION
  -- =========================================================================
  -- After adding all local commands to the shader entity, we must trigger
  -- the shader pipeline execution. We use queueScopedTransformCompositeRenderWithPipeline
  -- which properly calls executeEntityPipelineWithCommands() to process
  -- BatchedLocalCommands through shader passes.
  --
  -- The original queueScopedTransformCompositeRender only executes child commands
  -- in local space but NEVER calls the shader pipeline - hence text didn't render.
  -- =========================================================================
  if use_shader_pipeline and command_buffer and command_buffer.queueScopedTransformCompositeRenderWithPipeline then
    -- Debug: log the composite render call (once per entity)
    if not self._composite_logged then
      self._composite_logged = true
      print(string.format("[CBT] Triggering queueScopedTransformCompositeRenderWithPipeline for entity %s",
        tostring(self.shader_entity)))
    end
    command_buffer.queueScopedTransformCompositeRenderWithPipeline(
      layer_handle,
      registry,  -- Pass registry so C++ can call executeEntityPipelineWithCommands
      self.shader_entity,
      function()
        -- No additional drawing needed; local commands already added above
      end,
      self.z or 0,  -- z-index
      self.render_space  -- DrawCommandSpace (Screen or World)
    )
  end
end

return CommandBufferText
