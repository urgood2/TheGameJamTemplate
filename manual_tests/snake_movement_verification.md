# Snake Movement and Boundaries - Manual Verification Checklist

## Task: bd-pyyk
**Description**: Verify snake spawns correctly, movement stable, head stays in arena

## Verification Steps

### 1. Snake Spawning Verification
- [ ] **Initial spawn**: Snake spawns with 3 segments (soldier, apprentice, scout) as specified in PLAN.md
- [ ] **Segment order**: Head → tail order matches purchase order (soldier at head, scout at tail)
- [ ] **Position**: Snake spawns within arena boundaries, not clipping walls
- [ ] **Segment spacing**: Segments are properly spaced and connected visually
- [ ] **Physics**: All segments have collision bodies and respond to physics

### 2. Movement Stability
- [ ] **Smooth movement**: Snake head follows player input smoothly without jitter
- [ ] **Segment following**: Body segments follow the head in a natural snake-like motion
- [ ] **No gaps**: No gaps appear between segments during movement
- [ ] **No overlap**: Segments don't overlap excessively during turns
- [ ] **Turn radius**: Snake can make reasonable turns without breaking apart
- [ ] **Speed consistency**: Movement speed remains consistent across different input patterns

### 3. Arena Boundary Behavior
- [ ] **Head containment**: Snake head cannot move outside arena boundaries
- [ ] **Boundary collision**: Head stops or slides along boundary walls appropriately
- [ ] **Body behavior**: Body segments stay within arena when head hits boundary
- [ ] **Corner handling**: Snake handles arena corners correctly without glitching
- [ ] **No wall penetration**: No part of the snake clips through arena walls

### 4. Physics Integration
- [ ] **Collision detection**: Snake segments properly detect collisions with enemies
- [ ] **Contact events**: Contact collector properly registers segment-enemy overlaps
- [ ] **Position sync**: Runtime entity positions match pure logic positions
- [ ] **Entity cleanup**: No phantom entities or position desync issues

### 5. Visual Quality
- [ ] **Segment rendering**: All segments render correctly at their physics positions
- [ ] **Head indicator**: Player can clearly identify which segment is the head
- [ ] **Smooth animation**: Movement appears fluid at normal frame rates
- [ ] **No visual artifacts**: No flickering, stretching, or other visual glitches

## Expected Behavior (from PLAN.md)

### Snake Controller Specifications
- Snake head follows player input for movement
- Body segments follow in head→tail order
- Minimum length: 3 segments
- Maximum length: 8 segments
- Purchase order defines segment order (append to tail)

### Arena Configuration
- Arena has defined boundaries with padding
- Snake movement is constrained to arena bounds
- Contact damage occurs when segments overlap with enemies

## Common Issues to Watch For

### Movement Problems
- Segments separating or stretching unnaturally
- Head moving too fast for body to follow
- Jerky or stuttering movement
- Input lag or unresponsive controls

### Boundary Issues
- Snake head escaping arena bounds
- Segments clipping through walls
- Inconsistent boundary collision behavior
- Snake getting stuck in corners

### Physics Issues
- Segments not detecting enemy contact
- Position desync between visual and logical positions
- Collision detection failing intermittently
- Entity cleanup not happening properly

## Test Scenarios

### Basic Movement
1. Move snake in straight lines (up, down, left, right)
2. Make gradual turns in all directions
3. Make sharp 90-degree turns
4. Make rapid direction changes

### Boundary Testing
1. Move snake head directly into each wall
2. Slide snake along each wall edge
3. Test movement in all four corners
4. Try to escape arena bounds from different angles

### Length Variations
1. Test with minimum length (3 segments)
2. Test with maximum length (8 segments)
3. Test with various lengths in between
4. Verify behavior when length changes during gameplay

## Verification Results

**Date**: ___________
**Tester**: ___________
**Build**: ___________

### Overall Assessment
- [ ] PASS - All verification criteria met
- [ ] PARTIAL - Some issues found (document below)
- [ ] FAIL - Critical issues prevent proper functionality

### Issues Found
(Document any problems discovered during verification)

### Notes
(Additional observations or recommendations)

---

**Note**: This verification must be performed in the actual game environment with visual feedback and player controls. The automated tests verify logic correctness, but manual testing is required to verify user experience quality.