#pragma once
#include "events.hpp"
#include "components.hpp"
#include "combat_math.hpp"

// Resolves damage bundle through the pipeline and applies to target HP.
// Emits DamageDealt/DamageTaken events if emitEvents=true.
void ResolveAndApplyDamage(entt::entity attacker,
                           entt::entity defender,
                           DamageBundle& bundle,
                           Context& cx,
                           bool emitEvents);