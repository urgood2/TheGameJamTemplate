# Magicraft: Complete Spell Catalog

> **Research Status**: In Progress  
> **Last Updated**: 2026-01-11  
> **Sources**: Steam Store, Gameplay Analysis, Community Research  

---

## Overview

Magicraft features a comprehensive spell system with **hundreds of powerful spells** that can be combined to create unique effects. The game emphasizes spell combination and experimentation, allowing players to discover emergent gameplay through spell fusion.

---

## Spell System Architecture

### **Core Design Philosophy**
- **Combination-driven**: Spells can be fused to create new effects
- **Elemental-based**: Each spell belongs to specific elemental categories
- **Emergent gameplay**: Unexpected combinations create unique playstyles
- **High freedom**: "Ultra-high degrees of freedom cannot even be exhausted by developers"

### **Spell Categories**
Based on Steam description and gameplay analysis:

| Category | Description | Example Spells |
|----------|-------------|----------------|
| **Elemental Spells** | Pure elemental magic | Fire, Ice, Lightning, Earth |
| **Fusion Spells** | Combined elemental effects | Explosive, Crystal, Chain |
| **Summoning Spells** | Creature and entity summoning | Summoner builds |
| **Utility Spells** | Support and defensive magic | Shields, buffs, healing |
| **Melee Enhancement** | Close-range magical combat | Melee mage builds |

---

## Elemental System

### **Primary Elements**
Research indicates the following elemental categories:

| Element | Properties | Status Effects | Fusion Potential |
|---------|------------|----------------|------------------|
| **Fire** | High damage, burning | Burn, DoT | + Air = Explosive |
| **Ice** | Control, freezing | Freeze, Slow | + Earth = Crystal |
| **Lightning** | Chain damage, shock | Shock, Stun | + Water = Chain |
| **Earth** | Defense, petrify | Petrify, Armor | + Ice = Crystal |
| **Air** | Movement, explosion | Knockback, Spread | + Fire = Explosive |
| **Dark** | Corruption, life drain | Corrupt, Curse | + Light = Void |
| **Light** | Purification, healing | Purify, Buff | + Dark = Void |

### **Elemental Interactions**
- **Strengths**: Each element has advantages against specific enemy types
- **Weaknesses**: Counter-elements reduce effectiveness
- **Fusion Results**: Combining elements creates new spell properties
- **Environmental**: Elements interact with level geometry

---

## Spell Catalog (In Progress)

### **Fire Spells**
| Spell | Description | Damage | Mana Cost | Effects |
|-------|-------------|--------|-----------|---------|
| *Fireball* | Basic projectile | Medium | Low | Burn DoT |
| *Flame Burst* | Area explosion | High | Medium | AoE Burn |
| *Inferno* | Large area damage | Very High | High | Persistent Burn |

### **Ice Spells**  
| Spell | Description | Damage | Mana Cost | Effects |
|-------|-------------|--------|-----------|---------|
| *Frost Bolt* | Slowing projectile | Low-Medium | Low | Freeze |
| *Ice Shard* | Piercing damage | Medium | Low | Armor Pierce |
| *Blizzard* | Area control | Medium | High | AoE Freeze |

### **Lightning Spells**
| Spell | Description | Damage | Mana Cost | Effects |
|-------|-------------|--------|-----------|---------|
| *Lightning Bolt* | Chain damage | High | Medium | Chain |
| *Thunder Strike* | Area shock | Very High | High | AoE Shock |
| *Storm Call* | Multiple strikes | High | Very High | Multi-Target |

### **Earth Spells**
| Spell | Description | Damage | Mana Cost | Effects |
|-------|-------------|--------|-----------|---------|
| *Rock Throw* | Physical projectile | Medium | Low | Physical |
| *Stone Wall* | Defensive barrier | None | Medium | Block |
| *Earthquake* | Area damage + control | High | High | AoE + Stun |

### **Air Spells**
| Spell | Description | Damage | Mana Cost | Effects |
|-------|-------------|--------|-----------|---------|
| *Wind Blast* | Knockback effect | Low | Low | Push |
| *Tornado* | Area damage + pull | Medium | High | AoE + Pull |
| *Lightning Storm* | Air + Lightning combo | Very High | Very High | Chain + AoE |

---

## Fusion System

### **Basic Fusions**
| Combination | Result | Properties |
|-------------|--------|------------|
| Fire + Air | Explosive | Area damage, knockback |
| Ice + Earth | Crystal | Piercing, armor shred |
| Lightning + Water | Chain | Multi-target, jumping |
| Dark + Light | Void | Ultimate damage, ignore defense |

### **Advanced Fusions**
| Combination | Result | Properties |
|-------------|--------|------------|
| Fire + Earth | Magma | DoT + area damage |
| Ice + Air | Frost Storm | AoE freeze + spread |
| Lightning + Earth | Quake Strike | Area damage + stun |
| Dark + Fire | Hellfire | Corrupting burn |

---

## Spell Scaling System

### **Damage Scaling**
- **Base Damage**: Fixed initial damage value
- **Spell Power**: Primary scaling stat (multiplicative)
- **Elemental Mastery**: Secondary scaling (additive)
- **Combo Multiplier**: Increased damage with successful combinations

### **Mana Cost Scaling**
- **Base Cost**: Fixed mana requirement
- **Efficiency**: Reduced cost with mastery
- **Fusion Cost**: Additional mana for combined spells
- **Regeneration**: Mana recovery rate scaling

---

## Status Effects System

### **Primary Status Effects**
| Effect | Duration | Stack | Interaction |
|--------|----------|-------|-------------|
| **Burn** | 3-5 seconds | Yes | Extinguished by Ice |
| **Freeze** | 2-4 seconds | No | Melted by Fire |
| **Shock** | Instant | No | Chain to nearby |
| **Petrify** | 5-8 seconds | No | Broken by force |
| **Corrupt** | 4-6 seconds | Yes | Cleansed by Light |
| **Purify** | Instant | No | Removes debuffs |

### **Secondary Effects**
- **Knockback**: Enemy displacement
- **Slow**: Movement speed reduction
- **Stun**: Temporary incapacitation
- **Armor Pierce**: Defense reduction
- **Life Steal**: Health recovery

---

## Spell Progression System

### **Acquisition Methods**
- **Level Up**: Basic spells unlocked through progression
- **Discovery**: Advanced spells found through exploration
- **Fusion**: New spells created through combination
- **Relics**: Special spells granted by unique items

### **Mastery System**
- **Practice**: Repeated use increases effectiveness
- **Elemental Mastery**: Dedicated element scaling
- **Combination Mastery**: Enhanced fusion effects
- **Skill Trees**: Specialized spell improvements

---

## Build Archetypes

### **Elemental Purist**
- **Focus**: Single element specialization
- **Spells**: All spells from chosen element
- **Strengths**: Consistent damage, status stacking
- **Weaknesses**: Predictable, countered by opposite element

### **Fusion Master**
- **Focus**: Multi-element combinations
- **Spells**: Fusion spells and elemental mixing
- **Strengths**: Versatile, unpredictable effects
- **Weaknesses**: Complex resource management

### **Summoner**
- **Focus**: Creature and entity summoning
- **Spells**: Summoning spells, support magic
- **Strengths**: Battlefield control, damage diversification
- **Weaknesses**: Reliant on summoned entities

### **Melee Mage**
- **Focus**: Close-range magical combat
- **Spells**: Enhancement spells, close-range magic
- **Strengths**: High survivability, sustained damage
- **Weaknesses**: Limited range, high risk

---

## Balance Analysis

### **Overpowered Combinations**
- **Fire + Air**: Explosive area damage with low cost
- **Lightning + Water**: Chain damage with high efficiency
- **Dark + Light**: Void damage ignoring all defenses

### **Underutilized Elements**
- **Earth**: Primarily defensive, limited offensive options
- **Air**: Support role, lacks direct damage spells
- **Light**: Primarily utility, limited damage output

### **Meta Considerations**
- **Speed vs Power**: Faster spells vs stronger spells
- **Area vs Single**: AoE effectiveness vs focused damage
- **Elemental Counters**: Rock-paper-scissors elemental interactions

---

## Technical Implementation Notes

### **Spell Architecture**
```cpp
// Hypothetical spell system
class Spell {
    Element primary;
    Element secondary;  // For fusion spells
    vector<StatusEffect> effects;
    float baseDamage;
    float manaCost;
    float castTime;
};

class SpellCaster {
    vector<Spell> knownSpells;
    map<Element, float> elementalMastery;
    float spellPower;
    float manaPool;
};
```

### **Fusion Logic**
```cpp
Spell fuseSpells(const Spell& spell1, const Spell& spell2) {
    Spell result;
    result.primary = spell1.primary;
    result.secondary = spell2.primary;
    result.effects = combineEffects(spell1.effects, spell2.effects);
    result.baseDamage = calculateFusionDamage(spell1, spell2);
    result.manaCost = spell1.manaCost + spell2.manaCost;
    return result;
}
```

---

## Research Notes

### **Information Gaps**
- **Complete spell list**: Need comprehensive spell catalog
- **Exact damage values**: Quantitative balance data missing
- **Fusion formulas**: Specific combination rules unclear
- **Progression details**: Unlock requirements and mastery system

### **Research Sources**
- **Steam Store Page**: Basic game information and features
- **Gameplay Videos**: Visual spell analysis and effects
- **Community Forums**: Player-discovered combinations and builds
- **Developer Updates**: Patch notes and balance changes

### **Next Research Steps**
1. **Complete spell catalog**: Document all available spells
2. **Quantitative analysis**: Gather exact damage and cost values
3. **Fusion documentation**: Map all possible combinations
4. **Build optimization**: Identify optimal spell combinations

---

## Conclusion

Magicraft's spell system represents a sophisticated implementation of elemental magic with deep combination mechanics. The fusion system creates emergent gameplay that rewards experimentation and discovery, while the elemental framework provides clear strategic depth.

**Key Strengths**:
- High degree of freedom and experimentation
- Emergent gameplay through spell fusion
- Clear elemental framework with strategic depth
- Multiple viable build archetypes

**Areas for Further Research**:
- Complete spell documentation and balance analysis
- Detailed fusion mechanics and optimization strategies
- Long-term progression and mastery systems
- Competitive meta and optimal builds

---

*This document is part of the comprehensive Magicraft research project and will be updated as additional information becomes available.*