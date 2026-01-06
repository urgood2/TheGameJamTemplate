local Triggers = {}

Triggers.COMBAT = {
    ON_ATTACK = "on_attack",
    ON_HIT = "on_hit",
    ON_KILL = "on_kill",
    ON_CRIT = "on_crit",
    ON_MISS = "on_miss",
    ON_BASIC_ATTACK = "on_basic_attack",
    ON_SPELL_CAST = "on_spell_cast",
    ON_CHAIN_HIT = "on_chain_hit",
    ON_PROJECTILE_HIT = "on_projectile_hit",
    ON_PROJECTILE_SPAWN = "on_projectile_spawn",
}

Triggers.DEFENSIVE = {
    ON_BEING_ATTACKED = "on_being_attacked",
    ON_BEING_HIT = "on_being_hit",
    ON_PLAYER_DAMAGED = "on_player_damaged",
    ON_BLOCK = "on_block",
    ON_DODGE = "on_dodge",
    ON_SHRUG_OFF = "on_shrug_off",
    ON_COUNTER_ATTACK = "on_counter_attack",
}

Triggers.MOVEMENT = {
    ON_STEP = "on_step",
    ON_STAND_STILL = "on_stand_still",
    ON_TELEPORT = "on_teleport",
    ON_DASH = "on_dash",
}

Triggers.STATUS = {
    ON_APPLY_STATUS = "on_apply_status",
    ON_REMOVE_STATUS = "on_remove_status",
    ON_STATUS_EXPIRED = "on_status_expired",
    
    ON_APPLY_BURN = "on_apply_burn",
    ON_APPLY_FREEZE = "on_apply_freeze",
    ON_APPLY_POISON = "on_apply_poison",
    ON_APPLY_BLEED = "on_apply_bleed",
    ON_APPLY_DOOM = "on_apply_doom",
    ON_APPLY_ELECTROCUTE = "on_apply_electrocute",
    ON_APPLY_CORROSION = "on_apply_corrosion",
    
    ON_DOT_TICK = "on_dot_tick",
    ON_DOT_EXPIRED = "on_dot_expired",
    
    ON_MARK_APPLIED = "on_mark_applied",
    ON_MARK_DETONATED = "on_mark_detonated",
}

Triggers.BUFF = {
    ON_BUFF_APPLIED = "on_buff_applied",
    ON_BUFF_REMOVED = "on_buff_removed",
    ON_BUFF_EXPIRED = "on_buff_expired",
    ON_POISE_GAIN = "on_poise_gain",
    ON_CHARGE_GAIN = "on_charge_gain",
    ON_INFLAME_GAIN = "on_inflame_gain",
    ON_BLOODRAGE_GAIN = "on_bloodrage_gain",
}

Triggers.PROGRESSION = {
    ON_ENTRANCE = "on_entrance",
    ON_WAVE_START = "on_wave_start",
    ON_WAVE_CLEAR = "on_wave_clear",
    ON_LEVEL_UP = "on_level_up",
    ON_EXPERIENCE_GAINED = "on_experience_gained",
}

Triggers.RESOURCE = {
    ON_HEAL = "on_heal",
    ON_MANA_SPENT = "on_mana_spent",
    ON_MANA_RESTORED = "on_mana_restored",
    ON_LOW_HEALTH = "on_low_health",
    ON_FULL_HEALTH = "on_full_health",
    ON_SELF_DAMAGE = "on_self_damage",
}

Triggers.ENTITY = {
    ON_SUMMON = "on_summon",
    ON_MINION_DEATH = "on_minion_death",
    ON_ENEMY_SPAWN = "on_enemy_spawn",
    ON_DEATH = "on_death",
    ON_RESURRECT = "on_resurrect",
}

Triggers.EQUIPMENT = {
    ON_EQUIP = "on_equip",
    ON_UNEQUIP = "on_unequip",
}

Triggers.TICK = {
    ON_TICK = "on_tick",
    ON_TURN_START = "on_turn_start",
    ON_TURN_END = "on_turn_end",
}

Triggers.CALCULATION = {
    CALCULATE_DAMAGE = "calculate_damage",
    CALCULATE_HEALING = "calculate_healing",
    CALCULATE_CRIT = "calculate_crit",
    CALCULATE_RESIST = "calculate_resist",
}

local function flattenTriggers()
    local all = {}
    for category, triggers in pairs(Triggers) do
        if type(triggers) == "table" then
            for name, value in pairs(triggers) do
                all[name] = value
                all[value] = value
            end
        end
    end
    return all
end

Triggers.ALL = flattenTriggers()

function Triggers.isValid(trigger)
    return Triggers.ALL[trigger] ~= nil
end

function Triggers.getCategory(trigger)
    for category, triggers in pairs(Triggers) do
        if type(triggers) == "table" and category ~= "ALL" then
            for name, value in pairs(triggers) do
                if value == trigger then
                    return category
                end
            end
        end
    end
    return nil
end

return Triggers
