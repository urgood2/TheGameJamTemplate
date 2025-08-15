#include "loader_lua.hpp"
#include "components.hpp"

static TriggerPredicate Trigger_OnDeath() {
    return [](const Event& ev, Context&, entt::entity self){
        return ev.type == EventType::UnitDied && ev.source == self;
    };
}

static TriggerPredicate Trigger_OnCast() {
    return [](const Event& ev, Context&, entt::entity self){
        return ev.type == EventType::SpellCastResolved && ev.source == self;
    };
}

static TriggerPredicate Trigger_AllyAheadAttacks() {
    // fires on AttackStarted when primaryTarget's ally ahead is self, or when source is the ally ahead?
    // SAP flavor: “when an ally in front attacks” -> on AttackStarted, for units behind.
    //TODO: change based on game mechanics
    return [](const Event& ev, Context& cx, entt::entity self){
        // if (ev.type != EventType::AttackStarted) return false;
        // auto ahead = BoardHelpers::AllyAhead(cx.world, self);
        // return (ahead == ev.source);
        return false;
    };
}

static TriggerPredicate Trigger_AllyAheadFaints() {
    //TODO: change based on game mechanics
    return [](const Event& ev, Context& cx, entt::entity self){
        // if (ev.type != EventType::UnitDied) return false;
        // auto ahead = BoardHelpers::AllyAhead(cx.world, self);
        // return (ahead == ev.source);
        return false;
    };
}


void LuaContentLoader::load_traits(sol::table traits) {
    for (auto& kv : traits) {
        std::string name = kv.first.as<std::string>();
        sol::table def = kv.second.as<sol::table>();
        Ability a{}; a.name = ToSid(name);

        std::string on = def["trigger"]["on"].get_or(std::string("Passive"));
        if (on == "OnDeath") a.triggerPredicate = Trigger_OnDeath();
        else continue; // demo supports only OnDeath here

        // Target: RandomAllies(n)
        sol::optional<int> nopt = def["target"]["n"];
        int n = nopt.value_or(1);
        a.collectTargets = TargetRandomAllies(n, false);

        // Effects: ModifyStats (simple list)
        CompiledEffectGraph g; EffectOp op{}; op.code = EffectOpCode::ModifyStats; op.paramIndex = 0;
        Op_ModifyStats_Params mp{};
        sol::table effects = def["effects"];
        for (auto& e : effects) {
            sol::table t = e.second.as<sol::table>();
            if (std::string(t["op"]) == "ModifyStats") {
                sol::table params = t["params"];
                int idx = 0;
                for (auto& p : params) {
                    if (idx >= Op_ModifyStats_Params::Max) break;
                    sol::table pair = p.second.as<sol::table>();
                    std::string statName = pair["stat"]; float add = pair.get_or("add", 0.f); float mul = pair.get_or("mul", 0.f);
                    // Map a couple of example names → StatId. Extend as needed.
                    StatId sid = StatId::MaxHP;
                    if (statName == "MaxHP") sid = StatId::MaxHP;
                    else if (statName == "OffensiveAbility") sid = StatId::OffensiveAbility;
                    mp.stat[idx] = sid; mp.add[idx] = add; mp.mul[idx] = mul; ++idx; mp.count = idx;
                }
            }
        }
        g.modParams.push_back(mp); g.ops.push_back(op);
        a.effectGraph = std::move(g);

        db.add(a);
    }
}

void LuaContentLoader::load_spells(sol::table spells) {
    for (auto& kv : spells) {
        std::string name = kv.first.as<std::string>();
        sol::table def = kv.second.as<sol::table>();
        Ability a{}; a.name = ToSid(name);

        // Trigger
        std::string on = def["trigger"]["on"].get_or(std::string("OnCast"));
        if (on == "OnCast") a.triggerPredicate = Trigger_OnCast(); else continue;

        // Target
        std::string tfn = def["target"]["fn"].get_or(std::string("TargetEnemy"));
        if (tfn == "TargetEnemy" || tfn == "TargetPrimary") a.collectTargets = TargetPrimary();
        else if (tfn == "AllEnemies") a.collectTargets = TargetAllEnemies();
        else a.collectTargets = TargetPrimary();

        // Build effect graph: DealDamage + ApplyStatus + ApplyRR + KillExecute (optional)
        CompiledEffectGraph g;

        // DealDamage params
        Op_DealDamage_Params dp{}; dp.weaponScalar = def["effects"][1]["params"]["weaponScalar"].get_or(1.0f);
        // Simple: allow Cold flat as example
        dp.flat[(size_t)DamageType::Cold] = def["effects"][1]["params"]["flatCold"].get_or(0.0f);
        dp.tags = DmgTag_IsSkill;
        int dmgIndex = (int)g.dmgParams.size(); g.dmgParams.push_back(dp);
        g.ops.push_back(EffectOp{EffectOpCode::DealDamage, 0, 0, dmgIndex});

        // ApplyStatus (Chilled)
        Op_ApplyStatus_Params sp{}; sp.chilled = def["effects"][2]["params"]["chilled"].get_or(false);
        int stIndex = (int)g.statusParams.size(); g.statusParams.push_back(sp);
        g.ops.push_back(EffectOp{EffectOpCode::ApplyStatus, 0, 0, stIndex});

        // ApplyRR (Type1, Cold, value)
        Op_ApplyRR_Params rp{}; rp.type = DamageType::Cold; rp.rrType = RRType::Type1PctAdd;
        rp.value = def["effects"][3]["params"]["rr"].get_or(0.0f);
        int rrIndex = (int)g.rrParams.size(); g.rrParams.push_back(rp);
        g.ops.push_back(EffectOp{EffectOpCode::ApplyRR, 0, 0, rrIndex});

        // Optional: KillExecute at end if specified
        if (def["effects"][4].valid() && std::string(def["effects"][4]["op"]) == "KillExecute") {
            g.ops.push_back(EffectOp{EffectOpCode::KillExecute, 0, 0, -1});
        }

        a.effectGraph = std::move(g);

        // Cooldown
        a.cooldownSec = def.get_or("cooldown", 0.0f);

        db.add(a);
    }
}