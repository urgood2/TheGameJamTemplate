#include <entt/entt.hpp>
#include <sol/sol.hpp>
#include "bootstrap.hpp"
#include "components.hpp"
#include "pipelines.hpp"

int not_main() {
    entt::registry world;

    // Create two units: player and enemy
    entt::entity player = world.create();
    world.emplace<Team>(player, Team{0});
    world.emplace<Stats>(player);
    world.emplace<ResistPack>(player);
    world.emplace<LifeEnergy>(player, LifeEnergy{100.f, 100.f, 50.f, 50.f});
    world.emplace<KnownAbilities>(player);

    entt::entity enemy = world.create();
    world.emplace<Team>(enemy, Team{1});
    world.emplace<Stats>(enemy);
    world.emplace<ResistPack>(enemy);
    world.emplace<LifeEnergy>(enemy, LifeEnergy{120.f, 120.f, 30.f, 30.f});

    // Seed some base stats for demo
    auto& ps = world.get<Stats>(player);
    ps.Base(StatId::OffensiveAbility) = 200.f;
    ps.Base(StatId::CritMultiplier)   = 1.5f; // up to 3.5x allowed
    ps.RecomputeFinal();

    auto& es = world.get<Stats>(enemy);
    es.Base(StatId::DefensiveAbility) = 180.f;
    es.RecomputeFinal();

    // Bootstrap systems
    EngineBootstrap boot; boot.wireCore(world);

    // Load Lua content
    sol::state lua; lua.open_libraries(sol::lib::base, sol::lib::math, sol::lib::table);

    // Inject example content (same as content.lua below)
    lua.script(R"(
traits = {
  AntLikeBuff = {
    trigger = { on = "OnDeath" },
    target  = { fn = "RandomAllies", n = 1 },
    effects = {
      { op = "ModifyStats", params = {
          { stat = "MaxHP", add = 10 },
          { stat = "OffensiveAbility", add = 5 },
      }},
    }
  }
}

spells = {
  ShiverStrike = {
    trigger = { on = "OnCast" },
    target  = { fn = "TargetEnemy" },
    effects = {
      { op = "DealDamage", params = { weaponScalar = 1.10, flatCold = 25 } },
      { op = "ApplyStatus", params = { chilled = true } },
      { op = "ApplyRR",     params = { rr = 25 } },
      { op = "KillExecute" },
    },
    cooldown = 4.0
  }
}
    )");

    boot.loadContentFromLua(lua);

    // Give player the ShiverStrike ability
    auto& known = world.get<KnownAbilities>(player);
    known.list.push_back(AbilityRef{ ToSid("ShiverStrike") });

    // Prepare runtime context
    Context cx{ world };

    // Simulate casting ShiverStrike on enemy
    Event castStart{ EventType::SpellCastStarted, player, enemy, nullptr };
    world.ctx<EventBus>().dispatch(castStart, cx);

    Event castEnd{ EventType::SpellCastResolved, player, enemy, nullptr };
    world.ctx<EventBus>().dispatch(castEnd, cx);

    // Print resulting HP (pseudo; replace with your logger)
    auto& ehp = world.get<LifeEnergy>(enemy);
    // std::cout << "Enemy HP after ShiverStrike: " << ehp.hp << "\n";

    // Simulate player dying to show trait trigger (AntLikeBuff) if player had it
    // world.get<KnownAbilities>(player).list.push_back(AbilityRef{ ToSid("AntLikeBuff") });
    // Event died{ EventType::UnitDied, player, entt::null, nullptr };
    // world.ctx<EventBus>().dispatch(died, cx);

    return 0;
}