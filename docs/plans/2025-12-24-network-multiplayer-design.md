# Network Multiplayer Architecture Design

**Date:** 2024-12-24
**Status:** Approved
**Scope:** Minimal scaffolding for future multiplayer support

## Overview

Add co-op PvE multiplayer (2-4 players) with relaxed latency tolerance using peer-to-peer architecture where one player hosts.

### Goals
- Co-op PvE with some player-on-player interaction
- 2-4 players, 200ms+ latency acceptable
- Minimal scaffolding now, extensible later
- **Must not break existing single-player behavior**

### Non-Goals (for now)
- Competitive PvP with rollback netcode
- Dedicated server infrastructure
- Anti-cheat beyond host authority

---

## Core Architecture: Command-State Separation

### Current Flow (Single-Player)
```
Input → Direct State Mutation → Render
```

### Network-Ready Flow
```
Input → Command → [Network] → Validated State Mutation → Render
```

### Key Principles
1. **Commands** are small, serializable messages ("Player 1 wants to move right")
2. **State mutations** happen in ONE place (the host)
3. **Existing actual/visual split** is leveraged (clients predict visual, host confirms actual)
4. **Lua gameplay code stays unchanged** — runs on host only

---

## Network Message Types

### Client → Host (Commands)

| Message | Data | When Sent |
|---------|------|-----------|
| `PlayerInput` | `{ tick, moveDir, aimPos, buttons }` | Every frame with input |
| `ActionRequest` | `{ actionType, targetEntity, params }` | Card plays, abilities |
| `EventAck` | `{ eventId }` | Confirm receipt of important events |

### Host → Clients (State)

| Message | Data | When Sent |
|---------|------|-----------|
| `WorldSnapshot` | `{ tick, entities[], deletedIds[] }` | 10-20x/sec |
| `EntitySpawn` | `{ entityId, type, initialState }` | Entity created |
| `EntityDestroy` | `{ entityId, reason }` | Entity dies/despawns |
| `GameEvent` | `{ eventType, data }` | Combat events, pickups |

---

## Serialization (Network + Saves)

### Unified Approach
Network snapshots and save files use the same serialization code:

```
┌─────────────────────────────────────────────────────┐
│              Serializable Component                 │
│  (each component defines how to pack/unpack itself) │
└─────────────────────────────────────────────────────┘
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
    ┌──────────┐  ┌──────────┐  ┌──────────┐
    │ Network  │  │   Save   │  │  Replay  │
    │ Snapshot │  │   File   │  │  Frame   │
    └──────────┘  └──────────┘  └──────────┘
```

### Component Sync Priority

| Component | Network | Save | Notes |
|-----------|---------|------|-------|
| Transform (actual) | ✅ | ✅ | Position, rotation, scale |
| Health/Stats | ✅ | ✅ | Core gameplay |
| GOAPComponent | ❌ | ✅ | AI rebuilds from goals |
| AnimationQueue | ❌ | ❌ | Visual-only |
| Script table data | ✅ (key fields) | ✅ | Via `netSync` declaration |
| Physics velocity | ✅ | ✅ | For prediction |
| Inventory/Cards | On change | ✅ | Event-based |

### NetworkIdentity Component

```cpp
struct NetworkIdentity {
    uint32_t netId;           // Stable across network/saves
    uint8_t ownerPlayerId;    // 0 = host/server owned

    bool isLocallyControlled() const {
        return ownerPlayerId == networkManager.localPlayerId();
    }
};
```

### EnTT Integration

Uses native `entt::snapshot` and `entt::loader`:

```cpp
// Saving / Sending
entt::snapshot{registry}
    .entities(archive)
    .component<Transform>(archive)
    .component<Health>(archive)
    .component<NetworkIdentity>(archive);

// Loading / Receiving
entt::loader{registry}
    .entities(archive)
    .component<Transform>(archive)
    .component<Health>(archive)
    .component<NetworkIdentity>(archive);
```

---

## C++ Implementation

### New Files

```
src/systems/network/
├── network_manager.hpp/.cpp    # ENet wrapper, connection state
├── network_messages.hpp        # Message structs + serialization
├── network_identity.hpp        # NetworkIdentity component
├── snapshot.hpp/.cpp           # EnTT snapshot helpers
└── network_lua_bindings.cpp    # Expose to Lua
```

### NetworkManager Interface

```cpp
class NetworkManager {
public:
    enum class Role { None, Host, Client };

    void hostGame(uint16_t port);
    void joinGame(const std::string& address, uint16_t port);
    void disconnect();

    void sendCommand(const Command& cmd);
    void broadcastState(const Snapshot& snapshot);
    void broadcastEvent(const GameEvent& event);

    void poll();  // Call each frame

    Role getRole() const;
    bool isHost() const { return role == Role::Host; }
    uint8_t getLocalPlayerId() const;

    std::function<void(uint8_t playerId)> onPlayerJoined;
    std::function<void(uint8_t playerId)> onPlayerLeft;
    std::function<void(const Command&)> onCommandReceived;
    std::function<void(const Snapshot&)> onSnapshotReceived;
    std::function<void(const GameEvent&)> onEventReceived;
};
```

### Backward Compatibility

```cpp
// Helper used throughout codebase
inline bool isAuthoritative() {
    return networkManager.getRole() != NetworkManager::Role::Client;
}
```

| Scenario | `isAuthoritative()` | Gameplay runs? |
|----------|---------------------|----------------|
| Single-player | `true` | ✅ Normal |
| Host | `true` | ✅ Normal |
| Client | `false` | ❌ Visuals only |

### Main Loop Integration

```cpp
void game::update(float delta) {
    networkManager.poll();  // No-op when Role::None

    if (isAuthoritative()) {
        // === EXISTING UPDATE CODE, UNTOUCHED ===
        existingUpdateLogic(delta);
        // ========================================

        if (networkManager.isHost()) {
            broadcastSnapshot();
        }
    } else {
        applyLatestSnapshot();
        updateVisualsOnly(delta);
    }
}
```

---

## Lua Integration

### New Lua API

```lua
network.isAuthoritative()  -- true for single-player and host
network.isHost()           -- true only when hosting
network.isClient()         -- true only when connected as client
network.isOnline()         -- true in any multiplayer mode
network.localPlayerId()    -- 0 for host, 1-3 for clients
network.broadcast(eventType, data)    -- Host only
network.sendCommand(commandType, data) -- Client only
```

### Pattern: Events Split into Logic + Presentation

```lua
signal.register("enemy_killed", function(entity)
    if network.isAuthoritative() then
        grantXP(entity)
        spawnLoot(entity)
        network.broadcast("enemy_killed", { entityId = entity })
    end
    -- Presentation always runs
    playDeathEffect(entity)
    sound.play("enemy_death")
end)
```

### Pattern: Player Input as Commands

```lua
function onPlayerClickCard(card, target)
    if network.isAuthoritative() then
        playCard(card, target)
    else
        network.sendCommand("play_card", {
            cardId = card.id,
            targetId = target
        })
    end
end
```

### Pattern: Script Sync Fields

```lua
local Enemy = Node:extend()
Enemy.netSync = { "health", "currentState", "targetEntity" }
```

---

## System-Specific Details

### Physics Synchronization

**Approach:** Host-authoritative (recommended for relaxed latency)

- Only host runs `physicsWorld->Update()`
- Clients receive positions via snapshot
- Springs smooth visual interpolation

```cpp
void applySnapshotToPhysics(entt::entity e, float x, float y) {
    physics.SetBodyPosition(e, x, y);
    // Springs interpolate visual position smoothly
}
```

### Entity Ownership

| Entity Type | Owner | Reasoning |
|-------------|-------|-----------|
| Player character | Respective client | Responsive input |
| Enemies | Host | Consistent AI |
| Projectiles | Host | Authoritative hits |
| World/pickups | Host | Shared state |

### Late Join

```cpp
void onPlayerJoined(uint8_t playerId) {
    Snapshot fullSnapshot = createFullSnapshot();
    sendToPlayer(playerId, fullSnapshot);

    auto playerEntity = spawnPlayer(playerId);
    broadcastEvent("player_joined", { playerId, playerEntity });
}
```

### Random Number Sync

```lua
function initGame(seed)
    math.randomseed(seed)
    random.setSeed(seed)
end
```

---

## Networking Library

**Choice:** ENet

- Lightweight UDP with reliable + unreliable channels
- Works on all platforms including web (via adapters)
- Minimal dependencies
- Easy to swap later if needed

---

## Testing Strategy

Use TDD to ensure:
1. Single-player regression tests pass
2. Host simulation matches single-player behavior
3. Client receives and applies state correctly
4. Late join / reconnection works
5. Disconnection handled gracefully

---

## Future Extensions (Not in Scope Now)

- Delta compression for bandwidth optimization
- Client-side physics prediction
- Relevancy filtering (only send nearby entities)
- Dedicated server mode (headless host)
- Replay recording

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
