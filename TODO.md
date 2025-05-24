


# ✅ TODOs: Organized by Category

## 🧠 General Design / Architecture

## Kinda high priority
- [ ] use backgrounds & images for the tooltip text
- [ ] modal layers for ui
- [ ] not sure if object pool is being discarded upon game exit.
- [ ] highlight outline size is wrong. how to fix?
- [ ] how to disable collision for invisible ui boxes??
- [ ] z-layer based rendering for ui:
```cpp
// Pseudocode: assume each entity has a `LayerOrderComponent`
std::vector<entt::entity> entities;
registry.view<Transform, LayerOrderComponent>().each([&](auto entity, auto& transform, auto& layer) {
    entities.push_back(entity);
});

// Sort by layer.z ascending (lower layers checked first)
std::sort(entities.begin(), entities.end(), [&](entt::entity a, entt::entity b) {
    return registry.get<LayerOrderComponent>(a).z < registry.get<LayerOrderComponent>(b).z;
});
```
- [ ] link onscreen keyboard with text input -> click text field -> show keyboard -> link keyboard buttons with string stored -> enter pressed, close keyboard
- [ ] how to do z-layer based collision detection for ui:
```cpp
// Render
std::sort(entities.begin(), entities.end(), [&](entt::entity a, entt::entity b) {
    return registry.get<LayerOrderComponent>(a).z < registry.get<LayerOrderComponent>(b).z;
});
DrawEntities(entities);

// Collision (e.g., for mouse click)
std::sort(entities.begin(), entities.end(), [&](entt::entity a, entt::entity b) {
    return registry.get<LayerOrderComponent>(a).z > registry.get<LayerOrderComponent>(b).z;
});
for (auto e : entities) {
    if (MouseOverlaps(registry.get<Transform>(e))) {
        HandleClick(e);
        break; // topmost hit only
    }
}
```
- [ ] rect caching - just store in a map based on values? Otherwise just generate new one & add to map
- [ ] Need to test pipeline rendering w/ scaling for animations 
- [ ] New localization system needs to be tested.
- [ ] Context handling for modal dialogs (controller focus saving between windows) & controller run-through for the various ui types implemented (support for shoulder buttons, dpad, etc. when relevant) -> maybe do controller later, just implement modality / layers
- [ ] make variations of texture shaders based on voucher sheen/polychrome
- [ ] implement voucher sheen -> use new overlay draw system to do it
- [ ] example collision optimization class
```cpp
// BroadPhaseGrid.hpp
#pragma once

#include <unordered_map>
#include <vector>
#include <utility>
#include <cmath>
#include <array>
#include <entt/entt.hpp>

struct AABB {
    float x, y, w, h;
};

inline bool AABBOverlap(const AABB &a, const AABB &b) {
    return !(a.x + a.w < b.x || b.x + b.w < a.x ||
             a.y + a.h < b.y || b.y + b.h < a.y);
}

// Optional helper to auto-generate an AABB from Transform and Size components
struct Transform {
    struct Vec2 { float x, y; } position;
};

struct Size {
    float width, height;
};

inline AABB MakeAABBFromEntity(entt::registry &registry, entt::entity e) {
    const auto &t = registry.get<Transform>(e);
    const auto &s = registry.get<Size>(e);

    float scaleX = 1.0f, scaleY = 1.0f;
    if (auto *sc = registry.try_get<struct Scale>(e)) {
        scaleX = sc->x;
        scaleY = sc->y;
    }

    float width = s.width * scaleX;
    float height = s.height * scaleY;

    return AABB{
        t.position.x,
        t.position.y,
        width,
        height
    };
}

class BroadPhaseGrid {
public:
    using GridKey = std::pair<int, int>;

    BroadPhaseGrid(float cellSize = 128.0f)
        : m_cellSize(cellSize) {}

    void Clear() {
        m_grid.clear();
    }

    void Insert(entt::entity e, const AABB &aabb) {
        GridKey key = GetGridKey(aabb.x, aabb.y);
        m_grid[key].push_back({e, aabb});
    }

    void InsertAutoAABB(entt::registry &registry, entt::entity e) {
        AABB aabb = MakeAABBFromEntity(registry, e);
        Insert(e, aabb);
    }

    template <typename Func>
    void ForEachPossibleCollision(Func &&callback) {
        static const std::array<GridKey, 9> neighborOffsets = {{
            {-1, -1}, {0, -1}, {1, -1},
            {-1,  0}, {0,  0}, {1,  0},
            {-1,  1}, {0,  1}, {1,  1}
        }};

        for (const auto &[cell, list] : m_grid) {
            for (size_t i = 0; i < list.size(); ++i) {
                for (size_t j = i + 1; j < list.size(); ++j) {
                    callback(list[i].first, list[j].first);
                }
            }

            for (const auto &[dx, dy] : neighborOffsets) {
                if (dx == 0 && dy == 0) continue;
                GridKey neighbor = {cell.first + dx, cell.second + dy};
                if (m_grid.find(neighbor) == m_grid.end()) continue;

                for (auto &[e1, a1] : list) {
                    for (auto &[e2, a2] : m_grid[neighbor]) {
                        if (AABBOverlap(a1, a2)) {
                            callback(e1, e2);
                        }
                    }
                }
            }
        }
    }

    std::vector<entt::entity> FindOverlapsWith(entt::registry &registry, BroadPhaseGrid &broadphase, entt::entity entityA) {
      AABB target = MakeAABBFromEntity(registry, entityA);
      auto key = broadphase.GetGridKey(target.x, target.y);

      std::vector<entt::entity> results;

      // Check this cell and neighbors
      std::array<std::pair<int, int>, 9> neighborOffsets = {{
          {-1, -1}, {0, -1}, {1, -1},
          {-1,  0}, {0,  0}, {1,  0},
          {-1,  1}, {0,  1}, {1,  1}
      }};

      for (auto [dx, dy] : neighborOffsets) {
          auto neighborKey = std::make_pair(key.first + dx, key.second + dy);
          auto it = broadphase.m_grid.find(neighborKey);
          if (it == broadphase.m_grid.end()) continue;

          for (auto &[otherE, otherAABB] : it->second) {
              if (otherE == entityA) continue; // skip self
              if (AABBOverlap(target, otherAABB)) {
                  results.push_back(otherE);
              }
          }
      }

      return results;
  }

private:
    float m_cellSize;

    GridKey GetGridKey(float x, float y) const {
        return {
            static_cast<int>(std::floor(x / m_cellSize)),
            static_cast<int>(std::floor(y / m_cellSize))
        };
    }

    std::unordered_map<GridKey, std::vector<std::pair<entt::entity, AABB>>> m_grid;
};
```

usage:
```cpp
// Per-frame update loop
broadphase.Clear();

// Re-insert updated AABBs for all entities this frame
registry.view<Transform, Size>().each([&](entt::entity e, auto&, auto&) {
    broadphase.InsertAutoAABB(registry, e);
});

// Run collision logic only between nearby likely pairs
broadphase.ForEachPossibleCollision([&](entt::entity a, entt::entity b) {
    // Check collision, resolve overlap, handle response
});

// collision between given entity A and others
std::vector<entt::entity> collidedEntities = FindOverlapsWith(registry, broadphase, entityA);
for (auto e : collidedEntities) {
    // handle entityA vs e collision
}
```

- [ ] Implement more UI element types:
  
  - [ ] Cycles (radio buttons)
    - Displays a current selection (current_option_val)
    - Has left/right buttons to cycle through a list of args.options
    - args.focus_args.type = 'cycle' allows d-pad and shoulder input to be utilized
    - Visually indicates the current position with pips (unless args.no_pips) -> pips are just tiny rects, given unique ids (pip1, pip2), and change color depending on whether they are selected or not. They are added to a row component. Then the row added below the text
    - Binds to an external data value in ref_table[ref_value]
    - Can trigger a callback when changed
    - Supports keyboard/controller interaction and shoulder button overlays
  - [ ] Alerts -> just ui boxes with a dynamic text component that has a moving exclamation mark.
  - [ ] Tooltips -> ui boxes with rows/columns with backgrounds + text of varying colors + sometimes dynamic text for effect. There are drag, hover tooltips, each of which should be tested. Also don't make them be re-created every time, just cache them with the owner entity and destroy them later

- [ ] Utilize controller focus interactivity focus funneling in the above ui
    - [ ] redirect_focus_to: "When navigating focus, skip me and send it to this node instead."
    - [ ] claim_focus_from: "I'm a proxy node, but real input focus is handled by the node I'm representing."
- [ ] Text input (with cursor displayed, etc, software keyboard)

### MISC. RENDERING
- [ ] higher shadow on hovered items, draw above everything else. How? -> add height offset to shadow I guess -> use layer z-order for this

### LAUNCH CODE
- [ ] Shader materials, choose 2 or 3 and make them work for sprites (apply sprite sheet scaling) - including maybe an overall shadow pass like in snkrx?
- [ ] Participate in game jam or do a little test game jam on my own to make everything ready
- [ ] make everything compile for web

---

## Immediate laters

- [ ] shake not working, scramble not working. Slight stall when the app loads on windows, not sure why.
- [ ] some new text effects https://chatgpt.com/share/6809c567-486c-800a-a0db-e2dd955643aa
- Function to expand only a part of the ninepatch image (left corner for text, etc.). For use with kenney ui
- [ ] Option to set images for hover/ not hover/ clicked separately instead of using hover colors (one or the other). 
- [ ] Option to draw something over the button for select marker (instead of chosen circle bob)
- [ ] text tag documentation (img, anim) -> static ui / (img) -> dynamic text
- [ ] Rendering for animated entities should respect uiconfig's color variable for tint if the master entity has a uiconfig (is a uielement OBJECT type)
- [ ] shadows for sprites with shader pipeline, these need to be integrated with the shaders themselves (or use separate shadow pass) -> just render the final image twice with tint, should work
- [ ] change dissove on foil, etc. shaders, can't be a copy of balatro's
- [ ] tween colors for inventory ui, show hover indicator with draw() function
- [ ] Skill tree, refer to bytepath
- [ ] Text highlight efect - show same text overlaid, which vanishes upwa
- [ ] Use simple art style + scale down technique for visual prettiness
- [ ] something to replace current dissolve effect?
- [ ] some particle ideas:
  - [ ] particles - appear, move to a certain point via tweening, disappear
  - [ ] particles - wavering trail of rectangles behind a moving object + circle that flashes into view
  - [ ] particles - basic shapes changing size or other properties
  - [ ] particles- spinnig segmented circle which flahses then vanishes
  - [ ] particles - lightning-shaped irregular lines branching out all at once, then vanishing
- [ ] Some shaders don't work with the multi-pass system I have. 
- [ ] rounded rect needs testing - outline doesn't seem to work right all the time
- [ ] simple lighting shader with normal maps
- [ ] AddDrawTransformEntityWithAnimationWithPipeline needs to be tested.
- [ ] Some shaders, simple ones, which can be layered fro sprites and serve as a backbone for other additions later on. (drop shadow, holoram, 3d skew, sheen)
- [ ] button presses need to shift down text as well (dynamic text)
- [ ] Add support for UI element and box alignment to rotation/scale when bound to transforms.
- [ ] Highlights (like card selection highlights) -> just a uibox that is an empty outline, attached to another uibox. -> do for controller input later
- [ ] Need to apply individual sprite atlas uv change to every shader that will be used with sprites & create web versions
- [ ] Fix clicking + dragging not working unless hover is enabled.
- [ ] Make hover optional for clicking to work.
- [ ] Ensure UI elements are not clickable by default unless specified.
- [ ] rect shapes are made clickable by default in game.cpp. why do nested ones not click?
- [ ] UIbox should align itself again if its size changes. right now it does not.
- [ ] Impplement optional shader support for individual ui elements (or entire ui element trees)
- [ ] outline interiors look too square
- [ ] UI context switching for controller context savving (which button was focused, excluding butons from context in the presence of an overlay)
- [ ] Dynamic text has a problem where center/right alignment breaks ui element placement. Keep it as left aligned and use the ui element alightment, and you should be fine
- [ ] UI objects in ui elements might call renew alignment on ui box every time. need to check this.
- [ ] Add shader variations:
Suggestions for Gloss/Shine Shader Variations
🔷 Material-Focused Shines
    Brushed Metal – directional highlights with anisotropic streaks based on tangents.
    Velvet Sheen – edge-based soft highlights with fuzzy falloff (rim lit, but diffused).
    Lacquer/Plastic – hard specular with sharp, clean falloff + slight clear coat shine.
    Worn Metal – gloss modulated by grunge/noise masks; procedural wear and tear.
    Pearlescent – multi-layered interference hues depending on view angle and light angle.
    Holographic – shifting diffraction-like rainbow highlights from camera angle.
🔷 Stylized/Procedural Effects
    Ramp-based Specular (Toon Shine) – non-linear specular ramping using a 1D texture or math step function.
    Anime Glint – animated diagonal lines or sparkles that pulse across edges.
    Sheen Lines (Vista Glow) – trailing glow point that animates around a border (like high-end foil cards).
    Moving Bokeh Reflection – light spots (fake lens bokeh) that flow across the surface.
🔷 Overlay/Multipass Ideas
    Environment Map Reflection – even without actual environment maps, use fake cubemap glint swipes.
    Dynamic Bloom Outline – bright specular zones that spill light (bloom) and pulse.
    Double Coat Shader – simulate a thin transparent glossy coat over a rough underlayer.
    Scanline Sparkle – thin traveling scanline that causes strong sparkle on intersect.
🔷 Noise/Distortion Driven
    Distorted Shine – use noise to break up highlights into irregular reflections.
    Liquid Shine – sine-driven ripple effect modulating specular zones.
    Time-based Wave Gloss – sin(time + pos) driven specular strength shifting.
    Fractal Shine Veins – highlights that follow perlin/fractal veins.
    Edge Pulse Gloss – gloss increases along UV edges or silhouette outlines.

## 🧭 Later later laters *(future consideration)*
- [ ] make debug window that has debugDraw toggle
- [ ] some text effects randomly freeze, rotation seems off with renderscale other than 1
- [ ] optimize text implementation
- [ ] Determine how to programmatically modify frame times for particle animations.
- [ ] Consider using VBOs/IBOs for rendering to improve performance.
- [ ] "LATER: figure out button UIE more precisely"
- [ ] "LATER: bottom outline is sometimes jagged…"
- [ ] "LATER: when clicking nested buttons, outer button triggers hover…"
- [ ] "LATER: use VBO & IBOS for rendering"
- [ ] "LATER: ninepatch?"
- [ ] "LATER: Allow per-animation frame timing configuration in `particle::CreateParticle`.
- [ ] Determine how to handle automatic layout refresh when text changes (recenter or scale?).
- [ ] Add support for hover color change.
- [ ] rotation for ui elements & permanent attachment needs looking into, offsets don't work properly. 
- [ ] make color coding function for ui boxes (to generate color-coded tooltips)
- [ ] shadows for sprites using the sprites themselves (grayed out version)
- [ ] Fix jagged bottom outlines when buttons are scaled down.
- [ ] Controller input does not work on the mac.
- [ ] focus menu layers for controller not tested. It's simply used to save the previously focused node before opening something that will hog all the focus (onscreen keyboard for instance), which can then be restored after the thing is closed again. Mostly it's under_overlay that's used to mark buttons as being under overlay and mark them as not part of focusable list. Overlays are not implemented/tested and need to be debugged.
- [ ] focus navigation selection box should be a rounded rect, not a straight out rect
- [ ] probably make shadows stay in place vertically when shifting characters around in fancy text
- [ ] math.cpp needs cleanup
- [ ] refactoring input functionality
- [ ] shader TODOs
- [ ] spine rendering + layer integration https://chatgpt.com/share/67766376-ac24-800a-8711-f6fd64a6d733



# Done

- [x] adding animations for static text types (not for dynamic text)