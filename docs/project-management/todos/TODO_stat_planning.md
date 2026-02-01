

# stats to play with:

core stats:
        physique – Health & regen
        cunning – Offense, crit, pierce, bleed scaling
        spirit – Energy & magic-type scaling

bystats:
        health = 100 + physique×10 + spirit×2
        health_regen = max(0, (physique−10)×0.2)
        energy = spirit×10
        energy_regen = spirit×0.5

other stats:
        offensive_ability – Accuracy / crit chance
        defensive_ability – Evasion / crit resist
        armor – Flat damage reduction
        armor_absorption_bonus_pct – Bonus to absorbed amount

Physical/weapon:
        physical_modifier_pct (+1%/5 cunning)
        pierce_modifier_pct (+1%/5 cunning)
        bleed_duration_pct (+1%/5 cunning)
        trauma_duration_pct (+1%/5 cunning)

Elemental / Magic:
        fire_modifier_pct (+1%/5 spirit)
        cold_modifier_pct (+1%/5 spirit)
        lightning_modifier_pct (+1%/5 spirit)
        acid_modifier_pct (+1%/5 spirit)
        vitality_modifier_pct (+1%/5 spirit)
        aether_modifier_pct (+1%/5 spirit)
        chaos_modifier_pct (+1%/5 spirit)

DoT Durations:
        burn_duration_pct (+1%/5 spirit)
        frostburn_duration_pct (+1%/5 spirit)
        electrocute_duration_pct (+1%/5 spirit)
        poison_duration_pct (+1%/5 spirit)
        vitality_decay_duration_pct (+1%/5 spirit)

Damage Types:
        physical, pierce, bleed, trauma, fire, cold, lightning, acid, vitality, aether, chaos,
        (DOT): burn, frostburn, electrocute, poison, vitality_decay

Defense & Reaction Stats
        fire_resist_pct
        dodge_chance_pct
        reflect_damage_pct
        retaliation_fire
        retaliation_fire_modifier_pct
        block_chance_pct
        block_amount
        block_recovery_reduction_pct
        damage_taken_reduction_pct

Secondary Mechanic Stats:
        life_steal_pct – Heal from damage dealt
        crit_damage_pct – Extra crit multiplier
        cooldown_reduction – Faster ability reuse
        skill_energy_cost_reduction – Lower mana costs
        attack_speed – Faster basic attacks
        cast_speed – Faster spell casts

Resist Reduction (RR):
        rr1 / rr2 / rr3 tiers
        Applied per damage type (e.g. fire_rr)

- Skill conversions occur before gear conversions

Status & Buff Effects:
        barrier – Flat absorb shield
        percent_absorb_pct – Partial absorb
        healing_received_pct
        modify_stat – Temporary buff/debuff (+X%, duration)

Stack modes: replace / time_extend / count

# triggers to play with
OnHitResolved
OnHealed
OnCounterAttack
OnRRApplied
OnMiss
OnDodge
OnStatusExpired
OnDotApplied
OnDotExpired
OnDeath
OnExperienceGained
OnLevelUp
OnStatusRemoved


# hooking actions with stats.
Specific actions could scale something based on a stat.
    - fire_basic_bolt: scales with cunning for damage, spirit for burn duration


# Upgrades for stats
- Leveling up -> choose either physique, cunning, or spirit to level up.
- Artifacts can give conditional bonuses: 
    - on trigger, do X
    - if stat > X, do Y
    - if condition, do X or boost stat by Y
    - if set piece bonus, do X
- Artifacts can give scaling conversions:
    - X% of physique additionally counts toward cunning
- Gain an artifact that boosts:
    - health_regen
    - health/energy
    - energy_regen
    - offensive_ability
    - defensive_ability
    - armor
    - armor_absorption_bonus_pct
    - physical_modifier_pct
    - fire_modifier_pct
    - burn_duration_pct
    - life_steal_pct
    - crit_damage_pct
    - cooldown_reduction
    - skill_energy_cost_reduction
    - attack_speed
    - cast_speed
    - fire_resist_pct
    - dodge_chance_pct
    - reflect_damage_pct
    - retaliation_fire
    - retaliation_fire_modifier_pct
    - block_chance_pct
    - block_amount
    - block_recovery_reduction_pct
    - damage_taken_reduction_pct
    - healing_received_pct
    - modify_stat – Temporary buff/debuff (+X%, duration)
    
<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
