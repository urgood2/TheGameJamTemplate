-- assets/scripts/serpent/auto_attack_logic.lua
--[[
    Auto-Attack Logic Module

    Implements attack cadence, target selection, and attack event generation.
    Uses pure logic with deterministic ordering and timing.
]]

local auto_attack_logic = {}

--- Calculate distance between two points
--- @param x1 number First point X
--- @param y1 number First point Y
--- @param x2 number Second point X
--- @param y2 number Second point Y
--- @return number Distance between points
local function calculate_distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

--- Find the best target for a segment
--- Target selection: nearest enemy with distance <= effective_range, tie-break by lowest enemy_id
--- @param segment_snap table Segment combat snapshot
--- @param enemy_snaps table Array of enemy snapshots
--- @return table|nil Target enemy snapshot or nil if no valid target
local function find_target(segment_snap, enemy_snaps)
    if not segment_snap or not enemy_snaps then
        return nil
    end

    local best_target = nil
    local best_distance = math.huge

    -- Check all enemies for valid targets
    for _, enemy in ipairs(enemy_snaps) do
        if enemy and enemy.hp and enemy.hp > 0 and enemy.x and enemy.y then
            local distance = calculate_distance(
                segment_snap.x or 0, segment_snap.y or 0,
                enemy.x, enemy.y
            )

            -- Check if enemy is in range
            if distance <= (segment_snap.effective_range_num or 0) then
                -- Select best target (nearest, then lowest enemy_id for tie-break)
                local is_better = false
                if distance < best_distance then
                    is_better = true
                elseif distance == best_distance and best_target then
                    -- Tie-break by lowest enemy_id
                    if (enemy.enemy_id or 0) < (best_target.enemy_id or 0) then
                        is_better = true
                    end
                end

                if is_better then
                    best_target = enemy
                    best_distance = distance
                end
            end
        end
    end

    return best_target
end

--- Process attack cadence for a single segment
--- Implements: while cooldown <= 0 and target exists: emit attack, add effective_period to cooldown
--- @param segment_snap table Segment combat snapshot
--- @param enemy_snaps table Array of enemy snapshots
--- @param dt number Delta time in seconds
--- @return number, table Updated cooldown, array of attack events
local function process_segment_attacks(segment_snap, enemy_snaps, dt)
    local attack_events = {}
    local cooldown = segment_snap.cooldown_num or 0

    -- Reduce cooldown by delta time
    cooldown = cooldown - dt

    -- Attack cadence: while cooldown <= 0 and target exists
    while cooldown <= 0 do
        local target = find_target(segment_snap, enemy_snaps)

        if target then
            -- Emit attack event
            table.insert(attack_events, {
                type = "AttackEvent",
                attacker_instance_id = segment_snap.instance_id,
                target_enemy_id = target.enemy_id,
                base_damage_int = segment_snap.effective_attack_int or 0,
                attacker_x = segment_snap.x or 0,
                attacker_y = segment_snap.y or 0,
                target_x = target.x or 0,
                target_y = target.y or 0,
                distance = calculate_distance(
                    segment_snap.x or 0, segment_snap.y or 0,
                    target.x or 0, target.y or 0
                ),
                attacker_special_id = segment_snap.special_id
            })

            -- Add effective period to cooldown
            cooldown = cooldown + (segment_snap.effective_period_num or 1.0)
        else
            -- No target exists: clamp cooldown to 0 and stop
            cooldown = math.max(cooldown, 0)
            break
        end
    end

    return cooldown, attack_events
end

--- Main tick function for auto-attack logic
--- @param dt number Delta time in seconds
--- @param segment_combat_snaps table Array of segment combat snapshots in head→tail order
--- @param enemy_snaps table Array of enemy snapshots sorted by enemy_id
--- @return table, table Updated cooldowns by instance_id, array of attack events
function auto_attack_logic.tick(dt, segment_combat_snaps, enemy_snaps)
    local updated_cooldowns_by_instance_id = {}
    local all_attack_events = {}

    if not segment_combat_snaps or not enemy_snaps then
        return updated_cooldowns_by_instance_id, all_attack_events
    end

    -- Process each segment in head→tail order
    for _, segment_snap in ipairs(segment_combat_snaps) do
        if segment_snap and segment_snap.instance_id then
            -- Only process segments that are alive and have attack capability
            if segment_snap.effective_attack_int and segment_snap.effective_attack_int > 0 and
               segment_snap.effective_range_num and segment_snap.effective_range_num > 0 then

                local updated_cooldown, attack_events = process_segment_attacks(
                    segment_snap, enemy_snaps, dt
                )

                -- Store updated cooldown
                updated_cooldowns_by_instance_id[segment_snap.instance_id] = updated_cooldown

                -- Collect attack events
                for _, event in ipairs(attack_events) do
                    table.insert(all_attack_events, event)
                end
            else
                -- Segment can't attack, just update cooldown by reducing dt
                local current_cooldown = segment_snap.cooldown_num or 0
                updated_cooldowns_by_instance_id[segment_snap.instance_id] = math.max(current_cooldown - dt, 0)
            end
        end
    end

    return updated_cooldowns_by_instance_id, all_attack_events
end

--- Get attack summary for debugging
--- @param segment_snap table Segment combat snapshot
--- @param enemy_snaps table Array of enemy snapshots
--- @return table Attack summary with target info and range data
function auto_attack_logic.get_attack_summary(segment_snap, enemy_snaps)
    local target = find_target(segment_snap, enemy_snaps)

    return {
        instance_id = segment_snap.instance_id,
        has_target = target ~= nil,
        target_enemy_id = target and target.enemy_id,
        effective_range = segment_snap.effective_range_num or 0,
        effective_attack = segment_snap.effective_attack_int or 0,
        effective_period = segment_snap.effective_period_num or 1.0,
        cooldown = segment_snap.cooldown_num or 0,
        can_attack = (segment_snap.effective_attack_int or 0) > 0 and (segment_snap.effective_range_num or 0) > 0,
        target_distance = target and calculate_distance(
            segment_snap.x or 0, segment_snap.y or 0,
            target.x or 0, target.y or 0
        ) or nil
    }
end

--- Test the attack cadence implementation
--- @return boolean True if attack cadence logic is correctly implemented
function auto_attack_logic.test_attack_cadence()
    -- Mock data for testing
    local segment_snap = {
        instance_id = 1,
        x = 0,
        y = 0,
        effective_attack_int = 10,
        effective_range_num = 100,
        effective_period_num = 1.0,
        cooldown_num = -0.5 -- Ready to attack
    }

    local enemy_snaps = {
        { enemy_id = 1, x = 50, y = 0, hp = 30 }, -- In range
        { enemy_id = 2, x = 150, y = 0, hp = 20 } -- Out of range
    }

    -- Test that attack cadence produces attack when cooldown <= 0
    local updated_cooldown, attack_events = process_segment_attacks(segment_snap, enemy_snaps, 0)

    -- Should produce one attack and update cooldown
    if #attack_events ~= 1 then
        return false
    end

    -- Should target nearest enemy (enemy_id 1)
    if attack_events[1].target_enemy_id ~= 1 then
        return false
    end

    -- Cooldown should be increased by effective_period
    if updated_cooldown ~= 0.5 then -- -0.5 + 1.0 = 0.5
        return false
    end

    return true
end

return auto_attack_logic