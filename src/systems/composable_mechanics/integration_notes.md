Integration notes

Determinism: Plug in your deterministic RNG where noted (PTH roll, random targeters).

RR Durations: In this skeleton, RR is staged for the current resolution window. If you want timed RR debuffs, represent them as BuffInstance entries that apply to ResistPack.base or inject staging at DamageWillBeDealt.

Armor/Absorb: Replace the demo mapping with real ArmorProtection and an absorb pool component for GrantBarrier.

Performance: All hot paths are array math and function pointer calls. The tiny interpreter stores params in POD arrays; it’s cache-friendly and avoids std::variant.

Extensibility: Add new EffectOpCodes with a new param struct and a case in ExecuteEffectGraph. Add new targeters as more TargetFunc helpers. Add triggers by writing new TriggerPredicates and wiring them in the loader.

Add this to your registry context when you want per-turn limits to reset:

```cpp
auto& ts = world.ctx_or_set<TurnState>();
ts.id++; // call at StartTurn (shop) and/or StartOfBattle turns depending on your design
```

And if you plan to use Summon/Shop ops:

```cpp

world.set<EngineServices>(EngineServices{
    .spawnUnit = YourSpawnFn,        // entt::entity YourSpawnFn(Context&, Sid, int teamId, BoardPos)
    .refillShop = YourRefillShopFn   // void YourRefillShopFn(Context&)
});
```