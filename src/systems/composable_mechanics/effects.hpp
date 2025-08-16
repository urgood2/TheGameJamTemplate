#pragma once
#include <vector>
#include <functional>
#include <unordered_map>
#include <string>
#include "ids.hpp"
#include "stats.hpp"
#include "events.hpp"

// === Effect opcodes (tiny interpreter; POD params, no std::variant on hot path) ===
enum class EffectOpCode : uint8_t {
    Seq,                // run children in order
    ModifyStats,        // flat/mul deltas on targets
    DealDamage,         // use DamageBundle parameters
    ApplyStatus,        // set simple flags like Chilled
    ApplyRR,            // stage resistance reductions on defender for the current hit window
    GrantBarrier,       // flat absorb pool (not fully shown)
    KillExecute,        // kill if condition met
    NoOp,
    
    Repeat, LimitPerTurn,
    // board/meta
    PushUnit, ShuffleAllies, NudgeEnemyBehind,        // position ops
    TransformUnit, SummonUnit,
    CopyAbilityFrom, CopyItemTo, StealItem, RemoveItem, GiveItem,
    ModifyPlayerResource,                 // gold +=/-=/*= /=
    SetLevel, GiveExperience,
    ShopAddItem, ShopDiscountUnit, ShopDiscountItem, ShopRoll, ShopReplaceItems,
    StatSwapWithin, StatSwapBetween, StatCopyFrom, // swaps/copies
    ClassifyAdd,                                  // add a class/tag
    TakeLessDamageOneShot                          // "from next attack"
};

struct Op_ModifyStats_Params { // applies to each target
    // For simplicity we carry up to N deltas inline (tune N as needed)
    static constexpr int Max = 8;
    StatId stat[Max]{}; float add[Max]{}; float mul[Max]{}; int count{0};
};

struct Op_DealDamage_Params {
    float weaponScalar = 1.0f;
    std::array<float,(size_t)DamageType::COUNT> flat{};
    uint32_t tags = DmgTag_IsSkill;
};

struct Op_ApplyStatus_Params { bool chilled=false; bool frozen=false; bool stunned=false; float durationSec=0.f; };

struct Op_ApplyRR_Params { DamageType type; RRType rrType; float value = 0.f; float durationSec=0.f; };

struct EffectOp {
    EffectOpCode code{EffectOpCode::NoOp};
    // Index into child list (for Seq) or parameter blocks
    uint16_t firstChild = 0; // for Seq: starting index in a flat vector
    uint16_t childCount = 0;
    // Param storage indices
    int paramIndex = -1; // index into op-specific param pools
};



struct Op_Repeat_Params { int count=1; };
struct Op_LimitPerTurn_Params { int maxTimes=1; Sid key=0; };

struct Op_PushUnit_Params { int delta = 1; bool clamp=true; };  // +1 pushes back (SAP push)
struct Op_ShuffleAllies_Params { int radius = 5; bool alliesOnly=true; };

struct Op_TransformUnit_Params { Sid toSpecies; };
struct Op_SummonUnit_Params { Sid species; int count=1; int positionOffset=0; };

struct Op_CopyAbilityFrom_Params { Sid abilityName; bool untilEndOfBattle=true; };
struct Op_Item_Params { Sid item; }; // give/remove/steal/copy use this with context

struct Op_ModifyPlayerResource_Params { enum Op{Add,Sub,Mul,Div} op=Add; int value=0; };

struct Op_SetLevel_Params { int level=1; };
struct Op_GiveExperience_Params { int xp=1; };

struct Op_ShopAddItem_Params { Sid item; int count=1; };
struct Op_ShopDiscountUnit_Params { int amount=1; bool percent=false; };
struct Op_ShopDiscountItem_Params { int amount=1; bool percent=false; };
struct Op_ShopRoll_Params { int times=1; };
struct Op_ShopReplaceItems_Params { Sid from; Sid to; bool all=true; };

struct Op_StatSwapWithin_Params { StatId a, b; };
struct Op_StatSwapBetween_Params { StatId a, b; }; // applies across two targets
struct Op_StatCopyFrom_Params { StatId what; };

struct Op_ClassifyAdd_Params { Sid classTag; };

struct Op_TakeLessDamageOneShot_Params { float pct=0.5f; }; // 50% next hit reduction


// Compiled effect graph: flat node vector + param pools (cache-friendly)
struct CompiledEffectGraph {
    std::vector<EffectOp> ops;

    // Pools for existing ops
    std::vector<Op_ModifyStats_Params>  modParams;
    std::vector<Op_DealDamage_Params>   dmgParams;
    std::vector<Op_ApplyStatus_Params>  statusParams;
    std::vector<Op_ApplyRR_Params>      rrParams;

    // Pools for NEW ops
    std::vector<Op_Repeat_Params>       repParams;
    std::vector<Op_LimitPerTurn_Params> lptParams;

    std::vector<Op_PushUnit_Params>     pushParams;
    std::vector<Op_ShuffleAllies_Params> shuffleParams;

    std::vector<Op_TransformUnit_Params> transformParams;
    std::vector<Op_SummonUnit_Params>    summonParams;

    std::vector<Op_CopyAbilityFrom_Params> copyAbilityParams;
    std::vector<Op_Item_Params>            itemParams;

    std::vector<Op_ModifyPlayerResource_Params> playerResParams;

    std::vector<Op_SetLevel_Params>      setLevelParams;
    std::vector<Op_GiveExperience_Params> giveXpParams;

    std::vector<Op_ShopAddItem_Params>   shopAddItemParams;
    std::vector<Op_ShopDiscountUnit_Params> shopDiscUnitParams;
    std::vector<Op_ShopDiscountItem_Params> shopDiscItemParams;
    std::vector<Op_ShopRoll_Params>      shopRollParams;
    std::vector<Op_ShopReplaceItems_Params> shopReplaceParams;

    std::vector<Op_StatSwapWithin_Params>  swapWithinParams;
    std::vector<Op_StatSwapBetween_Params> swapBetweenParams;
    std::vector<Op_StatCopyFrom_Params>    statCopyParams;

    std::vector<Op_ClassifyAdd_Params>     classAddParams;

    std::vector<Op_TakeLessDamageOneShot_Params> nhmParams;
};



// Target function (Context + source + primTarget) -> list of entities
using TargetFunc = std::function<void(const Event&, Context&, std::vector<entt::entity>& out)>;

// Execute the compiled graph for a given (source, targets)
void ExecuteEffectGraph(const CompiledEffectGraph& g,
                        const Event& triggerEvent,
                        Context& cx,
                        entt::entity source,
                        const std::vector<entt::entity>& targets);
                        
// Optional: engine services hooks (place these in a shared header if you prefer)
struct EngineServices {
    entt::entity (*spawnUnit)(Context&, Sid species, int teamId) = nullptr;
    void (*refillShop)(Context&) = nullptr;
};