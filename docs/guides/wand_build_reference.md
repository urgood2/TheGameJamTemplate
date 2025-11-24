# Wand Build Reference (Design Snapshot)

This captures the “Achra-adjacent” structure for maximizing build variety with minimal new systems, plus the follow-up note.

## Core Shape (4 Knobs, Minimal Overlap)
- **Origin (culture/race):** 1 passive stat skew + 1 “prayer” active on a long cooldown; also biases tag weights (e.g., Fire+Brute origins nudge those tags).
- **Discipline (school):** Small fixed pack (~6 actions + ~6 mods) tagged with 2–3 tags from `TODO_design.md` (Fire/Ice/Summon/etc.); gates card pool per run to keep scope sane.
- **Wand Frame:** 5–6 templates that only change cast math (cast_block_size, shuffle, always_cast, overheat cap, trigger type); reuse existing wand fields.
- **Avatar (ascension):** Late-run macro mutation unlocked by a simple condition (kills/tag count/prayer uses); globally rewires a rule (e.g., multicast becomes loop; OnHit emits OnTick procs).

## Prayers (Activated Actives)
- One per Origin; balanced as single-button skills with tag hooks. Examples: Ember Psalm (Fire+Hazard): next 3 actions leave hazards; Glacier Litany (Ice+Defense): freeze + barrier, cooldown lowered when you block.
- Implement as data-driven spells using the existing effect API and EventBus/status system.

## Equipment (Kept Tiny)
- 2–3 slots (relic, charm, tome). Each grants: (a) 1 stat mod, (b) 1 tag-scaling proc or spell_mutator, (c) a resonance hook (“if you have 6+ Poison tags, poison spreads twice”).
- Treat “wand core” as a slot so no extra subsystem is needed.

## Card Pool Structure (Reuse Current Actions/Mods/Triggers)
- **Actions:** Keep existing projectile/effect/hazard/summon set; label with ≤2 tags and 1 role (clear/boss/control/support).
- **Mods:** Keep global but cap to ~8–10 evergreen mods + 2–3 discipline-specific variants; add 1–2 “meta” mods that touch cast order (loop, echo, shuffle).
- **Triggers:** Stick to 5 event triggers (time, kill, move, hit, low-HP) + 1 “ritual” trigger (pay HP/gold) for risk/reward.

## Synergy Rails (Lightweight)
- **Tag breakpoints:** Use the 3/5/7/9 boons from `TODO_design.md` as universal thresholds applied via deck snapshot.
- **Resonance pairs:** 6–8 hardcoded pairs that unlock micro-rules (Fire+Mobility = dashes ignite ground; Poison+Summon = minion hits extend poison).
- **Avatar predicates:** Avatars check the same tag totals or trigger counts, reusing the same bookkeeping.

## Progression Loop (Per Run)
- Draft order: Origin → Wand Frame → Discipline pack → prayer (from Origin) → 1 relic. During the run, add only discipline cards plus 2–3 neutral actions/mods and 1 neutral trigger.
- Mid-run choices: avatar unlock, 1 extra relic, 1 wand frame reroll.

## Examples
- Ember Nomad (Fire/Hazard) + Fanatic Frame (small casts, no shuffle) + Arcane Discipline → Avatar “Wildfire”: multicast becomes loop once per cast, hazards tick faster.
- Tundra Sentinel (Ice/Defense) + Engine Frame (big cast_block_size, long recharge) + Summon Discipline → Avatar “Citadel”: every 4th cast grants global barrier; summons inherit your freeze tag bonuses.
- Plague Scribe (Poison/Arcane) + Scatter Frame (shuffle, wide spread) + Mobility Discipline → Avatar “Miasma”: move-trigger casts also tick OnHit effects; poison spreads on movement-distance thresholds.

## Why This Stays Small
- Everything is data atop existing actions/mods/triggers; no new runtime subsystems beyond a tag-breakpoint evaluator, a small prayer cooldown manager, and an avatar unlock check.
- Uses existing combat/status/effect plumbing; wand frames are preset field bundles for `wand_executor`.
- Disciplines cap content scope while preserving draft freshness; avatars provide the “big upgrade” feel without new trees.

## Natural Next Steps (Appended)
Natural next steps if you want to try it: define 4 Origins + 4 Disciplines + 5 Wand Frames + 6 Avatars, wire tag breakpoints into the evaluator snapshot, and author prayers as plain spells using the existing effect API.
