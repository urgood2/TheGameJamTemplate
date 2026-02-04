# Shop Buy/Sell/Reroll - Manual Verification Checklist

## Task: bd-1la9
**Description**: Verify shop operations work correctly with gold accounting

## Test Environment Setup
- Start new Serpent run with known seed for reproducibility
- Note starting gold amount (should be 10 per PLAN.md)
- Enter shop phase after wave 1 completion

## Verification Steps

### 1. Shop Display and UI
- [ ] **Shop interface**: Shop UI shows correctly with 5 unit slots
- [ ] **Unit display**: Each slot shows unit icon, name, cost, and class
- [ ] **Gold display**: Current gold amount is visible and accurate
- [ ] **Button states**: Buy/sell/reroll buttons are clickable and visually distinct
- [ ] **Ready button**: "Ready for Combat" or equivalent button is present
- [ ] **Tier probabilities**: Units appear according to tier probability rules

### 2. Buy Operations
- [ ] **Valid purchase**: Can buy unit when gold >= unit cost
- [ ] **Insufficient gold**: Cannot buy unit when gold < unit cost (button disabled/error)
- [ ] **Gold deduction**: Gold decreases by exact unit cost when purchased
- [ ] **Snake addition**: Purchased unit is appended to tail of snake
- [ ] **Slot update**: Purchased unit disappears from shop slot
- [ ] **Length limit**: Cannot buy when at max length (8 segments) unless combine will occur
- [ ] **Combine trigger**: Buying 3rd copy of same unit at same level triggers combine

### 3. Sell Operations
- [ ] **Sell interface**: Can select segment from snake to sell
- [ ] **50% refund**: Selling refunds exactly floor(total_paid * 0.5) gold
- [ ] **Gold calculation**: total_paid = unit_cost * (3^(level-1)) correctly computed
- [ ] **Minimum length**: Cannot sell if it would reduce snake below 3 segments
- [ ] **Snake update**: Sold segment is removed from snake immediately
- [ ] **Order preservation**: Remaining segments maintain head→tail order

### 4. Reroll Operations
- [ ] **Reroll cost**: First reroll costs 2 gold, +1 gold per additional reroll in same shop
- [ ] **Cost display**: Current reroll cost is shown before clicking
- [ ] **Insufficient gold**: Cannot reroll when gold < reroll cost
- [ ] **Gold deduction**: Gold decreases by reroll cost when executed
- [ ] **Slot refresh**: All 5 shop slots get new random units
- [ ] **Cost increment**: Next reroll cost increases by 1 gold
- [ ] **Cost reset**: Reroll cost resets to 2 when entering new shop phase

### 5. Unit Combining Logic
- [ ] **Combine detection**: 3 copies of same unit at same level combine automatically
- [ ] **Level progression**: Combined unit becomes next level (level+1, max level 3)
- [ ] **Stats scaling**: Combined unit has stats = base * 2^(level-1)
- [ ] **Full heal**: Combined unit is set to full HP
- [ ] **Chain combines**: Multiple combines can happen in sequence
- [ ] **Length reduction**: Snake length decreases by 2 when combine occurs (3→1)

### 6. Gold Accounting Accuracy

#### Starting Gold
- [ ] **Initial amount**: New run starts with 10 gold
- [ ] **Wave rewards**: Gold increases by Gold_per_Wave(wave) = 10 + wave * 2

#### Transaction Verification
Test these specific scenarios and verify gold amounts:

**Scenario A**: Buy→Sell Chain
1. Start with 50 gold
2. Buy 6-cost unit → should have 44 gold
3. Sell same unit → should have 44 + floor(6 * 0.5) = 47 gold

**Scenario B**: Reroll Sequence
1. Start with 20 gold
2. First reroll → should have 18 gold (cost 2)
3. Second reroll → should have 15 gold (cost 3)
4. Third reroll → should have 11 gold (cost 4)

**Scenario C**: Combine Economics
1. Buy 3-cost unit (level 1) → -3 gold
2. Buy same unit again → -3 gold
3. Buy same unit third time → -3 gold, auto-combine to level 2
4. Sell combined unit → +floor(9 * 0.5) = +4 gold
5. Net change: -9 + 4 = -5 gold

### 7. Edge Cases and Error Handling
- [ ] **Empty shop slots**: Handle case where shop generation fails
- [ ] **Invalid selections**: Prevent selling head when only 3 segments remain
- [ ] **Rapid clicking**: Multiple rapid clicks don't cause double-transactions
- [ ] **State consistency**: Shop state matches pure logic state at all times
- [ ] **Ready validation**: Can only leave shop when snake has valid configuration

### 8. Shop Integration with Game Flow
- [ ] **Entry timing**: Shop appears between waves at correct times
- [ ] **HP persistence**: Unit HP carries over from combat to shop
- [ ] **Combine healing**: Only combines during shop phase heal to full
- [ ] **Exit transition**: "Ready" button correctly transitions to next combat
- [ ] **State cleanup**: Shop UI properly cleans up when exiting

## Expected Behavior (from PLAN.md)

### Shop Phase Rules
- 5 shop slots per shop phase
- Buy: append to tail before combine checks
- Sell: 50% refund, floor applied
- Reroll: 2g base, +1g per reroll within same shop phase
- Combine: 3 copies same unit same level → next level, full heal
- Min/max length: 3-8 segments enforced

### Gold Formula Verification
- Starting gold: 10
- Wave reward: 10 + wave * 2
- Unit costs: per unit definition (tier 1=3g, tier 2=6g, tier 3=12g, tier 4=20g)
- Sell refund: floor(unit_cost * 3^(level-1) * 0.5)

## Test Data Collection

### Sample Test Cases
Document these test scenarios with exact gold amounts:

| Scenario | Starting Gold | Action | Expected Gold | Actual Gold | Pass/Fail |
|----------|---------------|--------|---------------|-------------|-----------|
| Buy T1 unit | 10 | Buy 3-cost | 7 | ___ | ___ |
| Sell T1 unit | 7 | Sell L1 unit | 8 | ___ | ___ |
| First reroll | 8 | Reroll | 6 | ___ | ___ |
| Second reroll | 6 | Reroll | 3 | ___ | ___ |
| Insufficient gold | 2 | Buy 3-cost | 2 (no change) | ___ | ___ |

### Issues Found
(Document any discrepancies, bugs, or unexpected behavior)

### Performance Notes
(Note any UI lag, slow calculations, or other performance issues)

---

**Verification Results**

**Date**: ___________
**Tester**: ___________
**Build**: ___________

### Overall Assessment
- [ ] PASS - All shop operations work correctly
- [ ] PARTIAL - Minor issues found (document above)
- [ ] FAIL - Critical shop functionality broken

### Critical Issues
(Any issues that prevent normal shop usage)

### Recommendations
(Suggested improvements or fixes)

---

**Note**: This verification requires the full game environment with shop UI and interaction systems. Focus on gold accounting accuracy and ensuring all shop operations follow PLAN.md specifications exactly.