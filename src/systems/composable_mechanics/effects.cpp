#include "effects.hpp"
#include "board.hpp"
#include "components.hpp"
#include "pipelines.hpp"   // ResolveAndApplyDamage(...)
#include "ability.hpp"     // AbilityDatabase (or forward declare & remove include)
#include <algorithm>
#include <cassert>
#include <unordered_map>

// ----- Small helpers -----
static inline float  S(const Stats& s, StatId id)      { return s.final[(size_t)id]; }
static inline float& SB(Stats& s,    StatId id)        { return s.base[(size_t)id]; }

// Turn counter for LimitPerTurn
struct TurnState { int id = 0; }; // increment at StartTurn in your phase controller
struct PerTurnCounter {
    std::unordered_map<uint64_t,int> used;
    int turnId = 0;
};
static inline uint64_t CounterKey(entt::entity owner, Sid key) {
    return (uint64_t)key << 32 | (uint32_t)owner;
}

// ===== Atomic runners (existing) =====
static void Run_ModifyStats(const Op_ModifyStats_Params& p, Context& cx, const std::vector<entt::entity>& targets) {
    for (auto e : targets) {
        auto& stats = cx.world.get<Stats>(e);
        for (int i = 0; i < p.count; ++i) {
            if (p.add[i] != 0.f) stats.AddFlat(p.stat[i], p.add[i]);
            if (p.mul[i] != 0.f) stats.AddPercent(p.stat[i], p.mul[i]);
        }
        stats.RecomputeFinal();
    }
}

static void Run_DealDamage(const Op_DealDamage_Params& p, const Event& ev, Context& cx, entt::entity source, const std::vector<entt::entity>& targets) {
    for (auto target : targets) {
        DamageBundle bundle{};
        bundle.weaponScalar = p.weaponScalar;
        bundle.flat = p.flat;
        bundle.tags = p.tags;
        ResolveAndApplyDamage(source, target, bundle, cx, /*emitEvents=*/true);
    }
}

static void Run_ApplyStatus(const Op_ApplyStatus_Params& p, Context& cx, const std::vector<entt::entity>& targets) {
    for (auto e : targets) {
        auto& st = cx.world.get_or_emplace<StatusFlags>(e);
        if (p.chilled) st.isChilled = true;
        if (p.frozen)  st.isFrozen  = true;
        if (p.stunned) st.isStunned = true;
        // TODO: schedule expiry using your timer system for p.durationSec
    }
}

static void Run_ApplyRR(const Op_ApplyRR_Params& p, Context& cx, const std::vector<entt::entity>& targets) {
    for (auto e : targets) {
        auto& rp = cx.world.get<ResistPack>(e);
        size_t idx = (size_t)p.type;
        switch (p.rrType) {
            case RRType::Type1PctAdd:     rp.rrType1Sum[idx] += p.value; break;
            case RRType::Type2PctReduced: rp.rrType2Max[idx] = std::max(rp.rrType2Max[idx], p.value); break;
            case RRType::Type3Flat:       rp.rrType3Max[idx] = std::max(rp.rrType3Max[idx], p.value); break;
        }
        // Duration: either staged per hit (current design) or convert to a timed buff.
    }
}

// ===== NEW ops: board/meta/shop =====
static void Run_PushUnit(const Op_PushUnit_Params& p, Context& cx, const std::vector<entt::entity>& targets, entt::entity source) {
    auto& world = cx.world;
    //TODO: implement this
    // for (auto e : targets) {
    //     int after = -1;
    //     if (auto* bp = world.try_get<BoardPos>(e)) {
    //         int ni = bp->index + p.delta;
    //         if (p.clamp) {
    //             ni = std::max(p.minIndex, std::min(p.maxIndex, ni));
    //         }
    //         bp->index = ni;
    //         after = ni;
    //     }
    //     if (after >= 0) {
    //         Event pushed{ EventType::EnemyPushed, source, e, nullptr };
    //         world.ctx<EventBus>().dispatch(pushed, cx);
    //     }
    // }
}

static void Run_ShuffleAllies(const Op_ShuffleAllies_Params& p, Context& cx, entt::entity self) {
    auto& r = cx.world;
    auto* ts = r.try_get<Team>(self);
    auto* ps = r.try_get<BoardPos>(self);
    if (!ts || !ps) return;

    // collect allies in lane within [index-radius, index+radius]
    std::vector<std::pair<int, entt::entity>> buf;
    auto view = r.view<BoardPos, Team>();
    int lo = ps->index - p.radius;
    int hi = ps->index + p.radius;
    for (auto it : view) {
        const auto& b = view.get<BoardPos>(it);
        const auto& t = view.get<Team>(it);
        if (t.teamId == ts->teamId && b.lane == ps->lane && b.index >= lo && b.index <= hi) {
            buf.emplace_back(b.index, it);
        }
    }
    if (buf.size() <= 1) return;

    // deterministic "shuffle": reverse (replace with RNG if you want)
    std::sort(buf.begin(), buf.end(), [](auto& a, auto& b){ return a.first < b.first; });
    std::reverse(buf.begin(), buf.end());

    // reassign indices compactly within [lo, lo + count - 1]
    for (size_t i = 0; i < buf.size(); ++i) {
        auto e = buf[i].second;
        r.get<BoardPos>(e).index = lo + (int)i;
    }
}

static void Run_TransformUnit(const Op_TransformUnit_Params& p, Context& cx, const std::vector<entt::entity>& targets) {
    // Minimal placeholder: add a class/tag equal to toSpecies.
    // In your engine, you may swap abilities, visuals, and base stats here.
    for (auto e : targets) {
        auto& ct = cx.world.get_or_emplace<ClassTags>(e);
        if (!HasClass(ct, p.toSpecies)) ct.tags.push_back(p.toSpecies);
    }
}

static void Run_SummonUnit(const Op_SummonUnit_Params& p, Context& cx, entt::entity source) {
    auto& r = cx.world;
    auto* ts = r.try_get<Team>(source);
    auto* ps = r.try_get<BoardPos>(source);
    if (!ts || !ps) return;

    //TODO: implement this
    // if (auto* es = r.try_ctx<EngineServices>()) {
    //     if (!(*es).spawnUnit) return; // no-op if not wired
    //     for (int i = 0; i < p.count; ++i) {
    //         BoardPos pos{ ps->lane, ps->index + p.positionOffset + i };
    //         entt::entity child = (*es).spawnUnit(cx, p.species, ts->teamId, pos);
    //         Event ev{ EventType::EnemySummoned, source, child, nullptr };
    //         r.ctx<EventBus>().dispatch(ev, cx);
    //     }
    // }
}

// ===== NEW ops: abilities/items =====
static void Run_CopyAbilityFrom(const Op_CopyAbilityFrom_Params& p, Context& cx, entt::entity self, const std::vector<entt::entity>& fromTargets) {
    //TODO: implement this
    // auto* dbPtr = cx.world.try_ctx<AbilityDatabase*>();
    // if (!dbPtr) return;
    // auto* db = *dbPtr;
    // if (!db) return;

    // for (auto src : fromTargets) {
    //     // Simpler: just add by name; you can check if src actually owns it if you want
    //     if (db->find(p.abilityName)) {
    //         auto& known = cx.world.get_or_emplace<KnownAbilities>(self);
    //         known.list.push_back(AbilityRef{ p.abilityName });
    //         // If temporary: attach a battle-duration flag/buff (not shown)
    //     }
    // }
}

static void Run_ItemGive(const Op_Item_Params& p, Context& cx, const std::vector<entt::entity>& targets) {
    for (auto e : targets) cx.world.emplace_or_replace<HeldItem>(e, HeldItem{ p.item });
}

static void Run_ItemRemove(Context& cx, const std::vector<entt::entity>& targets) {
    for (auto e : targets) if (cx.world.all_of<HeldItem>(e)) cx.world.remove<HeldItem>(e);
}

static void Run_ItemSteal(Context& cx, entt::entity thief, const std::vector<entt::entity>& victims) {
    for (auto v : victims) {
        if (auto* it = cx.world.try_get<HeldItem>(v)) {
            cx.world.emplace_or_replace<HeldItem>(thief, *it);
            cx.world.remove<HeldItem>(v);
        }
    }
}

static void Run_ItemCopyTo(const Op_Item_Params& p, Context& cx, entt::entity src, const std::vector<entt::entity>& targets) {
    Sid give = p.item;
    if (auto* it = cx.world.try_get<HeldItem>(src)) give = it->id;
    if (!give) return;
    for (auto e : targets) cx.world.emplace_or_replace<HeldItem>(e, HeldItem{ give });
}

// ===== NEW ops: player/shop =====
static void Run_ModifyPlayerResource(const Op_ModifyPlayerResource_Params& p, Context& cx) {
    //TODO: implement this
    // if (!cx.meta) return;
    // int& gold = cx.meta->player.gold;
    // switch (p.op) {
    //     case Op_ModifyPlayerResource_Params::Add: gold += p.value; break;
    //     case Op_ModifyPlayerResource_Params::Sub: gold -= p.value; break;
    //     case Op_ModifyPlayerResource_Params::Mul: gold *= p.value; break;
    //     case Op_ModifyPlayerResource_Params::Div: if (p.value!=0) gold /= p.value; break;
    // }
    // if (gold < 0) gold = 0;
}

static void Run_SetLevel(const Op_SetLevel_Params& p, Context& cx, const std::vector<entt::entity>& targets) {
    for (auto e : targets) {
        //TODO: implement this
        // cx.world.emplace_or_replace<Level>(e, Level{ p.level });
        // Event ev{ EventType::AllyLevelUp, e, entt::null, nullptr };
        // cx.world.ctx<EventBus>().dispatch(ev, cx);
    }
}
static void Run_GiveXP(const Op_GiveExperience_Params& p, Context& cx, const std::vector<entt::entity>& targets) {
    for (auto e : targets) {
        auto& xp = cx.world.get_or_emplace<Experience>(e);
        xp.xp += p.xp;
        // Your level-up logic can live here; emit AllyLevelUp when thresholds crossed.
    }
}

static void Run_ShopAddItem(const Op_ShopAddItem_Params& p, Context& cx) {
    // if (!cx.meta) return;
    //TODO: implement this
    // for (int i = 0; i < p.count; ++i) cx.meta->shop.items.push_back(ShopItem{ p.item, 1, false, 3 });
}

static void Run_ShopDiscountUnit(const Op_ShopDiscountUnit_Params& p, Context& cx) {
    //TODO: implement this
    // if (!cx.meta) return;
    // for (auto& u : cx.meta->shop.units) {
    //     if (p.percent) u.cost -= (u.cost * p.amount) / 100;
    //     else           u.cost -= p.amount;
    //     if (u.cost < 0) u.cost = 0;
    // }
}

static void Run_ShopDiscountItem(const Op_ShopDiscountItem_Params& p, Context& cx) {
    //TODO: implement this
    // if (!cx.meta) return;
    // for (auto& it : cx.meta->shop.items) {
    //     if (p.percent) it.cost -= (it.cost * p.amount) / 100;
    //     else           it.cost -= p.amount;
    //     if (it.cost < 0) it.cost = 0;
    // }
}

static void Run_ShopRoll(const Op_ShopRoll_Params& p, Context& cx) {
    //TODO: implement this
    // if (!cx.meta) return;
    // auto& sh = cx.meta->shop;
    // for (int t = 0; t < p.times; ++t) {
    //     // keep frozen; clear the rest
    //     sh.units.erase(std::remove_if(sh.units.begin(), sh.units.end(), [](const ShopUnit& u){ return !u.frozen; }), sh.units.end());
    //     sh.items.erase(std::remove_if(sh.items.begin(), sh.items.end(), [](const ShopItem& i){ return !i.frozen; }), sh.items.end());

    //     if (auto* es = cx.world.try_ctx<EngineServices>()) {
    //         if ((*es).refillShop) (*es).refillShop(cx);
    //     }
    //     Event ev{ EventType::RollShop, entt::null, entt::null, nullptr };
    //     cx.world.ctx<EventBus>().dispatch(ev, cx);
    // }
}

static void Run_ShopReplaceItems(const Op_ShopReplaceItems_Params& p, Context& cx) {
    //TODO: implement this
    // if (!cx.meta) return;
    // for (auto& it : cx.meta->shop.items) {
    //     if (!p.from || p.all) it.item = p.to;
    //     else if (it.item == p.from) it.item = p.to;
    // }
}

// ===== NEW ops: stats & classify =====
static void Run_StatSwapWithin(const Op_StatSwapWithin_Params& p, Context& cx, const std::vector<entt::entity>& targets) {
    for (auto e : targets) {
        auto& s = cx.world.get<Stats>(e);
        std::swap(SB(s, p.a), SB(s, p.b));
        s.RecomputeFinal();
    }
}
static void Run_StatSwapBetween(const Op_StatSwapBetween_Params& p, Context& cx, const std::vector<entt::entity>& targets) {
    if (targets.size() < 2) return;
    auto& a = cx.world.get<Stats>(targets[0]);
    auto& b = cx.world.get<Stats>(targets[1]);
    std::swap(SB(a, p.a), SB(b, p.b));
    a.RecomputeFinal(); b.RecomputeFinal();
}
static void Run_StatCopyFrom(const Op_StatCopyFrom_Params& p, Context& cx, const std::vector<entt::entity>& targets) {
    if (targets.size() < 2) return;
    auto& from = cx.world.get<Stats>(targets[0]);
    for (size_t i = 1; i < targets.size(); ++i) {
        auto& to = cx.world.get<Stats>(targets[i]);
        SB(to, p.what) = S(from, p.what);
        to.RecomputeFinal();
    }
}

static void Run_ClassifyAdd(const Op_ClassifyAdd_Params& p, Context& cx, const std::vector<entt::entity>& targets) {
    for (auto e : targets) {
        auto& c = cx.world.get_or_emplace<ClassTags>(e);
        if (!HasClass(c, p.classTag)) c.tags.push_back(p.classTag);
    }
}

// ===== NEW op: one-shot mitigation =====
static void Run_TakeLessDamageOneShot(const Op_TakeLessDamageOneShot_Params& p, Context& cx, const std::vector<entt::entity>& targets) {
    const float pct = std::clamp(p.pct, 0.f, 1.f);
    for (auto e : targets) cx.world.emplace_or_replace<NextHitMitigation>(e, NextHitMitigation{ pct });
}

// ===== Executor plumbing =====
static void ExecuteRange(const CompiledEffectGraph& g, uint16_t start, uint16_t count,
                         const Event& ev, Context& cx, entt::entity self, const std::vector<entt::entity>& targets);

static void ExecuteOp(const CompiledEffectGraph& g, const EffectOp& op,
                      const Event& ev, Context& cx, entt::entity self, const std::vector<entt::entity>& targets) {
    switch (op.code) {
        case EffectOpCode::Seq: {
            ExecuteRange(g, op.firstChild, op.childCount, ev, cx, self, targets);
        } break;

        case EffectOpCode::Repeat: {
            // TODO: implement this
            // const auto& rp = g.repParams[(size_t)op.paramIndex];
            // for (int i = 0; i < rp.count; ++i) ExecuteRange(g, rp.childStart, rp.childCount, ev, cx, self, targets);
        } break;

        case EffectOpCode::LimitPerTurn: {
            // TODO: implement this
            // auto& r = cx.world;
            // const auto& lp = g.lptParams[(size_t)op.paramIndex];
            // auto* ts = r.try_ctx<TurnState>();
            // auto& c  = r.ctx_or_set<PerTurnCounter>();
            // const int curTurn = ts ? ts->id : 0;
            // if (c.turnId != curTurn) { c.turnId = curTurn; c.used.clear(); }
            // const auto key = CounterKey(self, lp.key);
            // int used = c.used[key];
            // if (used < lp.maxTimes) {
            //     ExecuteRange(g, lp.childStart, lp.childCount, ev, cx, self, targets);
            //     c.used[key] = used + 1;
            // }
        } break;

        case EffectOpCode::ModifyStats:
            Run_ModifyStats(g.modParams[(size_t)op.paramIndex], cx, targets); break;

        case EffectOpCode::DealDamage:
            Run_DealDamage(g.dmgParams[(size_t)op.paramIndex], ev, cx, self, targets); break;

        case EffectOpCode::ApplyStatus:
            Run_ApplyStatus(g.statusParams[(size_t)op.paramIndex], cx, targets); break;

        case EffectOpCode::ApplyRR:
            Run_ApplyRR(g.rrParams[(size_t)op.paramIndex], cx, targets); break;

        case EffectOpCode::PushUnit:
            Run_PushUnit(g.pushParams[(size_t)op.paramIndex], cx, targets, self); break;

        case EffectOpCode::ShuffleAllies:
            Run_ShuffleAllies(g.shuffleParams[(size_t)op.paramIndex], cx, self); break;

        case EffectOpCode::TransformUnit:
            Run_TransformUnit(g.transformParams[(size_t)op.paramIndex], cx, targets); break;

        case EffectOpCode::SummonUnit:
            Run_SummonUnit(g.summonParams[(size_t)op.paramIndex], cx, self); break;

        case EffectOpCode::CopyAbilityFrom:
            Run_CopyAbilityFrom(g.copyAbilityParams[(size_t)op.paramIndex], cx, self, targets); break;

        case EffectOpCode::GiveItem:
            Run_ItemGive(g.itemParams[(size_t)op.paramIndex], cx, targets); break;

        case EffectOpCode::RemoveItem:
            Run_ItemRemove(cx, targets); break;

        case EffectOpCode::StealItem:
            Run_ItemSteal(cx, self, targets); break;

        case EffectOpCode::CopyItemTo:
            Run_ItemCopyTo(g.itemParams[(size_t)op.paramIndex], cx, self, targets); break;

        case EffectOpCode::ModifyPlayerResource:
            Run_ModifyPlayerResource(g.playerResParams[(size_t)op.paramIndex], cx); break;

        case EffectOpCode::SetLevel:
            Run_SetLevel(g.setLevelParams[(size_t)op.paramIndex], cx, targets); break;

        case EffectOpCode::GiveExperience:
            Run_GiveXP(g.giveXpParams[(size_t)op.paramIndex], cx, targets); break;

        case EffectOpCode::ShopAddItem:
            Run_ShopAddItem(g.shopAddItemParams[(size_t)op.paramIndex], cx); break;

        case EffectOpCode::ShopDiscountUnit:
            Run_ShopDiscountUnit(g.shopDiscUnitParams[(size_t)op.paramIndex], cx); break;

        case EffectOpCode::ShopDiscountItem:
            Run_ShopDiscountItem(g.shopDiscItemParams[(size_t)op.paramIndex], cx); break;

        case EffectOpCode::ShopRoll:
            Run_ShopRoll(g.shopRollParams[(size_t)op.paramIndex], cx); break;

        case EffectOpCode::ShopReplaceItems:
            Run_ShopReplaceItems(g.shopReplaceParams[(size_t)op.paramIndex], cx); break;

        case EffectOpCode::StatSwapWithin:
            Run_StatSwapWithin(g.swapWithinParams[(size_t)op.paramIndex], cx, targets); break;

        case EffectOpCode::StatSwapBetween:
            Run_StatSwapBetween(g.swapBetweenParams[(size_t)op.paramIndex], cx, targets); break;

        case EffectOpCode::StatCopyFrom:
            Run_StatCopyFrom(g.statCopyParams[(size_t)op.paramIndex], cx, targets); break;

        case EffectOpCode::ClassifyAdd:
            Run_ClassifyAdd(g.classAddParams[(size_t)op.paramIndex], cx, targets); break;

        case EffectOpCode::TakeLessDamageOneShot:
            Run_TakeLessDamageOneShot(g.nhmParams[(size_t)op.paramIndex], cx, targets); break;

        case EffectOpCode::GrantBarrier:
        case EffectOpCode::KillExecute:
        case EffectOpCode::NoOp:
        default:
            // Keep your previous implementations or extend here.
            break;
    }
}

static void ExecuteRange(const CompiledEffectGraph& g, uint16_t start, uint16_t count,
                         const Event& ev, Context& cx, entt::entity self, const std::vector<entt::entity>& targets) {
    for (uint16_t i = 0; i < count; ++i) {
        const auto& child = g.ops[(size_t)(start + i)];
        ExecuteOp(g, child, ev, cx, self, targets);
    }
}

void ExecuteEffectGraph(const CompiledEffectGraph& g,
                        const Event& ev,
                        Context& cx,
                        entt::entity source,
                        const std::vector<entt::entity>& targets) {
    ExecuteRange(g, /*start*/0, (uint16_t)g.ops.size(), ev, cx, source, targets);
}
