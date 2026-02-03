-- aseprite_merge_layers.lua
-- Merges layers from a source .aseprite file into a target .aseprite file
-- with prefixed layer names to avoid collisions.
--
-- Usage:
--   aseprite -b \
--     --script-param source=/path/to/source.aseprite \
--     --script-param target=/path/to/target.aseprite \
--     --script scripts/aseprite_merge_layers.lua
--
-- Exit codes (written to stdout as JSON):
--   {"status": "success", "layers_added": N}
--   {"status": "skipped", "reason": "layers_exist", "prefix": "..."}
--   {"status": "error", "reason": "..."}

local source_path = app.params["source"]
local target_path = app.params["target"]

-- Validate params
if not source_path or source_path == "" then
    print('{"status": "error", "reason": "missing source param"}')
    return
end

if not target_path or target_path == "" then
    print('{"status": "error", "reason": "missing target param"}')
    return
end

-- Extract prefix from source filename (without extension)
local prefix = source_path:match("([^/]+)%.aseprite$")
if not prefix then
    print('{"status": "error", "reason": "invalid source filename"}')
    return
end

-- Open source sprite
local source_sprite = Sprite{ fromFile = source_path }
if not source_sprite then
    print('{"status": "error", "reason": "failed to open source file"}')
    return
end

-- Open target sprite
local target_sprite = Sprite{ fromFile = target_path }
if not target_sprite then
    source_sprite:close()
    print('{"status": "error", "reason": "failed to open target file"}')
    return
end

-- Check if layers with this prefix already exist in target
for _, layer in ipairs(target_sprite.layers) do
    if layer.name:find("^" .. prefix .. "_") then
        source_sprite:close()
        target_sprite:close()
        print('{"status": "skipped", "reason": "layers_exist", "prefix": "' .. prefix .. '"}')
        return
    end
end

-- Expand target canvas if source is larger
local new_width = math.max(target_sprite.width, source_sprite.width)
local new_height = math.max(target_sprite.height, source_sprite.height)
if new_width > target_sprite.width or new_height > target_sprite.height then
    target_sprite:resize(new_width, new_height)
end

-- Ensure target has at least as many frames as source
while #target_sprite.frames < #source_sprite.frames do
    target_sprite:newEmptyFrame()
end

-- Copy layers from source to target
local layers_added = 0
for _, src_layer in ipairs(source_sprite.layers) do
    if src_layer.isImage then
        -- Create new layer in target with prefixed name
        local new_layer = target_sprite:newLayer()
        new_layer.name = prefix .. "_" .. src_layer.name

        -- Copy cels from source layer to new layer
        for _, src_cel in ipairs(src_layer.cels) do
            local frame_num = src_cel.frameNumber
            -- Ensure frame exists
            while #target_sprite.frames < frame_num do
                target_sprite:newEmptyFrame()
            end
            -- Create cel with copied image
            target_sprite:newCel(new_layer, frame_num, src_cel.image, src_cel.position)
        end

        layers_added = layers_added + 1
    end
end

-- Save target sprite
target_sprite:saveAs(target_path)

-- Clean up
source_sprite:close()
target_sprite:close()

print('{"status": "success", "layers_added": ' .. layers_added .. '}')
