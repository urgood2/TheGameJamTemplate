
#include <memory>
#include <chrono>

#if defined(PLATFORM_WEB)
#include "util/web_glad_shim.hpp"
#endif

#if defined(__EMSCRIPTEN__)
    #include <GLES3/gl3.h>
    #include <GLES2/gl2.h>
    #include <GLES2/gl2ext.h>
#else
    // #include <GL/gl.h>
    // #include <GL/glext.h>
#endif

#include "../util/utilities.hpp"
#include "../util/error_handling.hpp"
#include "../util/crash_reporter.hpp"

#include "graphics.hpp"
#include "globals.hpp"

#include "systems/input/controller_nav.hpp"


#include "../components/components.hpp"
#include "../components/graphics.hpp"

#include "game.hpp" // game.hpp must be included after components.hpp

#include "gui.hpp"
#include "raylib.h"
#include "raymath.h"

#include "../third_party/rlImGui/extras/IconsFontAwesome6.h"
#include "../third_party/rlImGui/imgui_internal.h"

#include "../third_party/navmesh//source/navmesh_include.hpp"

#include "../systems/shaders/shader_system.hpp"
#include "../systems/telemetry/telemetry.hpp"
#include "../systems/shaders/shader_pipeline.hpp"
#include "../systems/event/event_system.hpp"
#include "misc_fuctions.hpp"
#include "systems/ui/ui_data.hpp"
#include "../systems/sound/sound_system.hpp"
#include "../systems/text/textVer2.hpp"
#include "../systems/text/static_ui_text.hpp"
#include "../systems/ui/common_definitions.hpp"
#include "../systems/ui/inventory_ui.hpp"
#include "../systems/localization/localization.hpp"
#include "../systems/collision/broad_phase.hpp"
#include "../systems/collision/Quadtree.h"
#include "../systems/save/save_file_io.hpp"
#include "../systems/scripting/scripting_functions.hpp"
#include "../systems/scripting/scripting_system.hpp"
#include "core/events.hpp"
#include "systems/transform/transform_functions.hpp"
#include "../systems/ai/ai_system.hpp"
#include "spdlog/spdlog.h"
#include "systems/camera/camera_manager.hpp"
#include "testing/test_mode.hpp"
#if ENABLE_LDTK
#include "systems/ldtk_loader/ldtk_combined.hpp"
#endif
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"
#include "rlgl.h"
#include "systems/physics/physics_world.hpp"
#include "systems/chipmunk_objectivec/ChipmunkAutogeometry.hpp"
#include "systems/chipmunk_objectivec/ChipmunkTileCache.hpp"
#include "systems/chipmunk_objectivec/ChipmunkPointCloudSampler.hpp"
#include "systems/physics/transform_physics_hook.hpp"
#include "systems/scripting/binding_recorder.hpp"
#include "systems/spring/spring.hpp"
#include "systems/transform/transform.hpp"
#include "third_party/chipmunk/include/chipmunk/chipmunk.h"
#include "third_party/chipmunk/include/chipmunk/chipmunk_types.h"
#include "third_party/chipmunk/include/chipmunk/cpBB.h"
#include "systems/uuid/uuid.hpp"
#include "systems/composable_mechanics/bootstrap.hpp"
#include "systems/composable_mechanics/ability.hpp"

#include "systems/scripting/lua_hot_reload.hpp"
#include "sol/types.hpp"

using std::pair;

#define SPINE_USE_STD_FUNCTION
#include "spine/spine.h"
#include "third_party/spine_impl/spine_raylib.hpp"
#include "spine/AnimationState.h"
#include "spine/Bone.h"

#include <map>
#include <string>
#include <vector>

#include "util/common_headers.hpp"
#include "core/ui_definitions.hpp"

#include "systems/layer/layer.hpp"
#include "core/system_registry.hpp"
#include "systems/layer/layer_optimized.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include "systems/layer/layer_order_system.hpp"
#include "systems/input/input_functions.hpp"
#include "systems/ui/ui.hpp"
#include "systems/ui/util.hpp"
#include "systems/ui/handlers/handler_registry.hpp"
#include "systems/timer/timer.hpp"
#include "systems/particles/particle.hpp"
#include "systems/random/random.hpp"
#include "systems/second_order_dynamics/second_order_dynamics.hpp"
#include "systems/fade/fade_system.hpp"

#include "entt/entt.hpp"

#include "third_party/rlImGui/rlImGui.h"




#include "rlgl.h"


// AsteroidManager *asteroidManager = nullptr;

// NOTE: Legacy global entity declarations (player, transformEntity, childEntity*,
// uiBox, etc.) were removed as they were unused example code. Entity references
// should be stored in EngineContext or managed at scene scope.

// lua function handles
sol::protected_function luaMainInitFunc;
sol::protected_function luaMainUpdateFunc;
sol::protected_function luaMainDrawFunc;


float transitionShaderPositionVar = 0.f;

namespace game
{
    

    
    std::vector<std::string> fullscreenShaders;

    std::unordered_map<std::string, std::shared_ptr<layer::Layer>> s_layers{};
    
    std::string randomStringText{"HEY HEY!"
    };
    std::vector<std::string> randomStringTextList = {
        "Hello",
        "World",
        "This is a test",
        "Random text",
        "Another line",
        "More text here",
        "Just some random words",
        "Lorem ipsum dolor sit amet",
        "The quick brown fox jumps over the lazy dog",
        "Sample text for testing purposes"
    };
              
    std::vector<std::string> randomEffects = {
        "shake",
        "pulse",
        "rotate",
        "float",
        "bump",
        "wiggle",
        "slide",
        "pop",
        "spin",
        "fade",
        "highlight",
        "rainbow",
        "expand",
        "bounce",
        "scramble"
    };
    
    decltype(std::declval<entt::registry&>()
        .group<
        TextSystem::Text,
        AnimationQueueComponent,
        ui::InventoryGrid
        >()) objectsAttachedToUIGroup;

    bool gameStarted{false}; // if game state has begun (not in menu )

    // global variables
    // ----------------

    bool isPaused{false}, isGameOver{false};

    // GC performance tracking
    double g_lastGcPauseMs{0.0};
    double g_maxGcPauseMs{0.0};
    double g_avgGcPauseMs{0.0};
    size_t g_gcPauseSampleCount{0};

    // NOTE: Unused camera spring entity declarations were removed.
    // Camera springs are now managed by camera_manager.

    TextSystem::Text text;
    entt::entity textEntity{entt::null};

    
    // Somewhere at file-scope or in your collision namespace:
    static auto dedupePairs = [](const std::vector<std::pair<entt::entity, entt::entity>>& raw) {
        std::vector<std::pair<entt::entity, entt::entity>> out;
        out.reserve(raw.size());

        // Normalize (a,b) so a < b, skip self-pairs
        for (auto &p : raw) {
            auto a = p.first;
            auto b = p.second;
            if (a == b) continue;
            if (a > b) std::swap(a, b);
            out.emplace_back(a, b);
        }

        // Sort & unique
        std::sort(out.begin(), out.end(),
            [](auto &x, auto &y){
                return x.first < y.first
                    || (x.first == y.first && x.second < y.second);
            });
        out.erase(std::unique(out.begin(), out.end()), out.end());
        return out;
    };
    
    // Typedef so sol2 can bind it easily
    using WorldQT = quadtree::Quadtree<
        entt::entity,
        decltype(globals::getBoxWorld),
        std::equal_to<entt::entity>,
        float
    >;
    
    
    namespace luaqt {
        
        using namespace quadtree;

        inline Box<float> box_from_table(const sol::table& t) {
            return Box<float>(
                { t.get<float>("left"), t.get<float>("top") },
                { t.get<float>("width"), t.get<float>("height") }
            );
        }

        inline sol::table box_to_table(sol::this_state ts, const Box<float>& b) {
            sol::state_view L(ts);
            sol::table t = L.create_table();
            t["left"]   = b.left;
            t["top"]    = b.top;
            t["width"]  = b.width;
            t["height"] = b.height;
            return t;
        }

        void bind_quadtrees_lua(sol::state& L, WorldQT& world, WorldQT& ui)
        {
            // If you want, you can also bind Box, but not required if you use tables only.
            // L.new_usertype<quadtree::Box<float>>("Box", sol::no_constructor,
            //     "left",   &quadtree::Box<float>::left,
            //     "top",    &quadtree::Box<float>::top,
            //     "width",  &quadtree::Box<float>::width,
            //     "height", &quadtree::Box<float>::height
            // );

            // Disambiguate overloaded member names with sol::resolve
            auto add_fn    = sol::resolve<void(const entt::entity&)>(&WorldQT::add);
            auto remove_fn = sol::resolve<void(const entt::entity&)>(&WorldQT::remove);
            auto clear_fn  = &WorldQT::clear;

            L.new_usertype<WorldQT>("WorldQuadtree",
                sol::no_constructor,                            // <-- correct token

                "clear",  clear_fn,
                "add",    add_fn,
                "remove", remove_fn,

                // query({left,top,width,height}) -> array of entities
                "query", [](WorldQT& self, sol::this_state ts, sol::table qtbl) {
                    auto results = self.query(box_from_table(qtbl));
                    sol::state_view S(ts);
                    sol::table arr = S.create_table(static_cast<int>(results.size()), 0);
                    int i = 1;
                    for (auto& e : results) arr[i++] = e;       // assumes entt::entity is Lua-convertible in your project
                    return arr;
                },

                // find_all_intersections() -> { {a,b}, ... }
                "find_all_intersections", [](WorldQT& self, sol::this_state ts) {
                    auto pairs = self.findAllIntersections();
                    sol::state_view S(ts);
                    sol::table out = S.create_table(static_cast<int>(pairs.size()), 0);
                    int i = 1;
                    for (auto& p : pairs) {
                        sol::table pr = S.create_table(2, 0);
                        pr[1] = p.first;
                        pr[2] = p.second;
                        out[i++] = pr;
                    }
                    return out;
                },

                // get_bounds() -> {left,top,width,height}
                "get_bounds", [](WorldQT& self, sol::this_state ts) {
                    return box_to_table(ts, self.getBox());
                }
            );

            // Inject references to your existing instances (no Lua-side construction)
            L["quadtreeWorld"] = std::ref(world);
            L["quadtreeUI"]    = std::ref(ui);

            // Optional helper to make boxes from Lua quickly
            sol::table qmod = L["quadtree"].get_or_create<sol::table>();
            qmod.set_function("box", sol::overload(
                [](float l, float t, float w, float h) { return quadtree::Box<float>({l,t},{w,h}); },
                [](sol::table tbl) { return box_from_table(tbl); }
            ));
            
            // ------------------------------------------------------------
            // Quadtree bindings: BindingRecorder entries
            // ------------------------------------------------------------
            
            auto &rec = BindingRecorder::instance();

            // Types
            rec.add_type("WorldQuadtree");
            rec.add_type("Box"); // pseudo-type (Lua table with fields), still document it

            // Box (table) fields
            rec.record_property("Box",   {"left",   "number", "Left (x) position"});
            rec.record_property("Box",   {"top",    "number", "Top (y) position"});
            rec.record_property("Box",   {"width",  "number", "Width"});
            rec.record_property("Box",   {"height", "number", "Height"});

            // Injected instances (globals). If your recorder has a “record_global” helper, use it;
            // otherwise document them as properties on the (implicit) global table "" or a module.
            // Here we mark them as globals with brief descriptions.
            rec.record_property("", {"quadtreeWorld", "WorldQuadtree", "Spatial index for world-entities (injected C++ instance)."});
            rec.record_property("", {"quadtreeUI",    "WorldQuadtree", "Spatial index for UI-entities (injected C++ instance)."});

            // Module: quadtree (for helpers like quadtree.box)
            rec.add_type("quadtree"); // treat as a module namespace in docs

            // quadtree.box overloads
            rec.record_method("quadtree", {
                "box",
                "---@param self quadtree\n"
                "---@overload fun(self:quadtree, left:number, top:number, width:number, height:number): Box\n"
                "---@overload fun(self:quadtree, tbl:Box): Box\n"
                "---@return Box",
                "Creates a Box from numbers or from a table with {left, top, width, height}."
            });

            // WorldQuadtree instance methods

            // clear()
            rec.record_method("WorldQuadtree", {
                "clear",
                "---@param self WorldQuadtree\n"
                "---@return nil",
                "Removes all entities from the quadtree."
            });

            // add(e)
            rec.record_method("WorldQuadtree", {
                "add",
                "---@param e Entity\n"
                "---@return nil",
                "Inserts the entity into the quadtree (entity must have a known AABB)."
            });

            // remove(e)
            rec.record_method("WorldQuadtree", {
                "remove",
                "---@param e Entity\n"
                "---@return nil",
                "Removes the entity from the quadtree if present."
            });

            // query(box) -> Entity[]
            rec.record_method("WorldQuadtree", {
                "query",
                "---@param box Box\n"
                "---@return Entity[]",
                "Returns all entities whose AABBs intersect the given box."
            });

            // find_all_intersections() -> { {Entity, Entity}, ... }
            rec.record_method("WorldQuadtree", {
                "find_all_intersections",
                "---@param self WorldQuadtree\n"
                "---@return Entity[][]",
                "Returns a list of intersecting pairs as 2-element arrays {a, b}."
            });

            // get_bounds() -> Box
            rec.record_method("WorldQuadtree", {
                "get_bounds",
                "---@param self WorldQuadtree\n"
                "---@return Box",
                "Returns the overall bounds of the quadtree space."
            });

            // (Optional) Type notes for Entity & AABB expectation. If your recorder supports notes:
            rec.record_method("", {
                "_note_quadtree_entity_req",
                "---@private\n---@return nil",
                "Quadtree assumes each Entity queried/inserted has a retrievable AABB; "
                "your C++ side should ensure conversions to/from Box are consistent."
            });
        }

    } // namespace luaqt

    // New: per-layer shader stacks
    static std::unordered_map<std::string, std::vector<std::string>> s_layerShaders;

    // ---- Layer shader API ----
    inline void add_layer_shader(const std::string& layerName, const std::string& shaderName) {
        auto& vec = s_layerShaders[layerName];
        if (std::find(vec.begin(), vec.end(), shaderName) == vec.end())
            vec.push_back(shaderName);
    }

    inline void remove_layer_shader(const std::string& layerName, const std::string& shaderName) {
        auto it = s_layerShaders.find(layerName);
        if (it == s_layerShaders.end()) return;

        auto& vec = it->second;
        vec.erase(std::remove(vec.begin(), vec.end(), shaderName), vec.end());
        if (vec.empty()) s_layerShaders.erase(it);
    }

    inline void clear_layer_shaders(const std::string& layerName) {
        s_layerShaders.erase(layerName);
    }

    // ============================================================
    //  SHARED UNIFIED SHADER PIPELINE (ping-pong)
    // ============================================================
    // Applies shaders by alternating between mainCanvas and tempCanvas.
    // After an odd number of passes, result is in tempCanvas and must be
    // copied back to mainCanvas (with clearing to prevent stale data bleed).

    inline void run_shader_pipeline(
        std::shared_ptr<layer::Layer> layer,
        const std::vector<std::string>& pipeline,
        const std::string& mainCanvas = "main",
        const std::string& tempCanvas = "render_double_buffer"
    ) {
        if (pipeline.empty()) return;

        std::string src = mainCanvas;
        std::string dst = tempCanvas;

        for (const auto& shaderName : pipeline) {
            layer::DrawCanvasOntoOtherLayerWithShader(
                layer,
                src,
                layer,
                dst,
                0, 0, 0, 1, 1,
                WHITE,
                shaderName
            );
            std::swap(src, dst);
        }

        // Ensure result ends up back in mainCanvas
        if (src != mainCanvas) {
            // Guard: ensure mainCanvas exists
            auto canvasIt = layer->canvases.find(mainCanvas);
            if (canvasIt == layer->canvases.end()) {
                SPDLOG_WARN("run_shader_pipeline: mainCanvas '{}' not found", mainCanvas);
                return;
            }

            // Clear destination before drawing (prevents stale content bleed-through)
            BeginTextureMode(canvasIt->second);
            ClearBackground(BLANK);
            EndTextureMode();

            layer::DrawCanvasOntoOtherLayer(
                layer,
                src,
                layer,
                mainCanvas,
                0, 0, 0, 1, 1,
                WHITE
            );
        }
    }
    
    
    
/* --------------------------- reload game helper --------------------------- */
    void resetLuaRefs()
    {
        luaMainInitFunc.reset();
        luaMainUpdateFunc.reset();
        luaMainDrawFunc.reset();
        
        luaMainDrawFunc = sol::lua_nil;
        luaMainUpdateFunc = sol::lua_nil;
        luaMainInitFunc = sol::lua_nil;
    }

    // contains what needs to be done to re-initialize main after a reset, includes init methods from main.cpp that go beyond baseline init
    void reInitializeGame()
    {
        
        timer::TimerSystem::clear_all_timers();
        event_system::ClearAllListeners(); // drop Lua callbacks before nuking the Lua state
        localization::clearLanguageChangedCallbacks(); // drop localized UI callbacks (Lua-backed)
        
        globals::getRegistry().view<transform::Transform>().each([](auto entity, auto &t){
            transform::RemoveEntity(&globals::getRegistry(), entity);
        });
        
        globals::getRegistry().clear();
        
        // clear registry, timers, physics worlds, layers
        globals::physicsManager->clearAllWorlds();
        game::physicsWorld.reset();
        layer::UnloadAllLayers();
        ClearLayers();

        // Reset graphics state that persists across layers
        layer::render_stack_switch_internal::ForceClear("hot reload cleanup"); // clear render stack to avoid stale render targets
        shader_pipeline::ShaderPipelineUnload(); // unload shader pipeline render textures (re-inits on first use)
        EndBlendMode(); // reset OpenGL blend mode to default
        EndShaderMode(); // reset any active shader
        game::fullscreenShaders.clear(); // clear fullscreen shader list (fixes colors/transparency after reload)

        clear_layer_shaders("ui_layer");
        clear_layer_shaders("sprites");
        clear_layer_shaders("background");
        shaders::unloadShaders(); // drops shader callbacks/uniforms tied to Lua
        shaders::loadShadersFromJSON("shaders/shaders.json"); // reload shaders after unloading
        controller_nav::NavManager::instance().reset();
        
        // clear lua state and re-load
        resetLuaRefs();
        ai_system::masterStateLua = sol::state(); // reset lua state
        ai_system::init();
        
        globals::quadtreeUI.clear();
        globals::quadtreeWorld.clear();
        
        sound_system::ResetSoundSystem();
    
        input::Init(globals::getInputState(), globals::getRegistry(), globals::g_ctx);
        game::init();
        
    }
    
/* ---------------- helpers for culling scroll pane elements ---------------- */
    static inline bool rectsOverlap(const Rectangle& a, const Rectangle& b) {
        return !(a.x > b.x + b.width  || a.x + a.width  < b.x ||
                a.y > b.y + b.height || a.y + a.height < b.y);
    }

    static inline Rectangle paneViewport(entt::registry& R, entt::entity pane) {
        auto &xf = R.get<transform::Transform>(pane);
        return Rectangle{ xf.getActualX(), xf.getActualY(), xf.getActualW(), xf.getActualH() };
    }

    auto initAndResolveCollisionEveryFrame() -> void
    {
        using namespace quadtree;
        
        constexpr float buffer = 200.f;
        
        
        // world space collision detection
        
        

        // 1) build an expanded bounds rectangle
        //    (assumes worldBounds.x,y is the top-left and width/height are positive)
        Box<float> expandedBounds;
        expandedBounds.top = globals::worldBounds.getTopLeft().y - buffer;
        expandedBounds.left = globals::worldBounds.getTopLeft().x - buffer;
        expandedBounds.width = globals::worldBounds.getSize().x + 2 * buffer;
        expandedBounds.height = globals::worldBounds.getSize().y + 2 * buffer;

        // 2) reset the quadtree using the bigger area
        globals::quadtreeWorld = Quadtree<entt::entity, decltype(globals::getBoxWorld)>(
            expandedBounds,
            globals::getBoxWorld
        );

        // Populate the Quadtree Per Frame
        globals::getRegistry().view<transform::Transform, transform::GameObject, entity_gamestate_management::StateTag>(entt::exclude<collision::ScreenSpaceCollisionMarker, entity_gamestate_management::InactiveTag>)
            .each([&](entt::entity e, auto &transform, auto &go, auto &stateTag) {
                if (entity_gamestate_management::active_states_instance().is_active(stateTag) == false) return; // skip collision on inactive entities
                if (!go.state.collisionEnabled) return;
                auto box = globals::getBoxWorld(e);
                if (expandedBounds.contains(box)) {
                    // Add the entity to the quadtree if it is within the expanded bounds
                    globals::quadtreeWorld.add(e);
                } ;
            });
            
        // broad phase collision detection
        auto raw = globals::quadtreeWorld.findAllIntersections();
        
        // Deduplicate & normalize the pairs
        auto pairs = dedupePairs(raw);

        auto collisionFilterView = globals::getRegistry().view<collision::CollisionFilter>();

        // Single pass: notify each entity exactly once per partner
        for (auto [a,b] : pairs) {
            if (!globals::getRegistry().valid(a) || !globals::getRegistry().valid(b))
                continue;
            
            auto &fA = collisionFilterView.get<collision::CollisionFilter>(a);
            auto &fB = collisionFilterView.get<collision::CollisionFilter>(b);
            // bitwise filter:
            // if (fA.mask != 1 || fB.mask != 1) {
            //     SPDLOG_DEBUG("Collision filter mismatch: A mask {} category {}, B mask {} category {}", 
            //         fA.mask, fA.category, fB.mask, fB.category);
            // }
            if ((fA.mask & fB.category) == 0 || (fB.mask & fA.category) == 0)
                continue; // skip entirely
            
            // SPDLOG_DEBUG("Collision passed for filters: A mask {} category {}, B mask {} category {}", 
            //     fA.mask, fA.category, fB.mask, fB.category);


            // if (collision::CheckCollisionBetweenTransforms(&globals::getRegistry(), a, b) == false) 
            //     continue;

            // A → B
            // if (auto *sc = globals::getRegistry().try_get<scripting::ScriptComponent>(a)) {
            //     if (sc->hooks.on_collision.valid())
            //         sc->hooks.on_collision(sc->self, b);
            // }
            // // B → A
            // if (auto *sc = globals::getRegistry().try_get<scripting::ScriptComponent>(b)) {
            //     if (sc->hooks.on_collision.valid())
            //         sc->hooks.on_collision(sc->self, a);
            // }
        }
        
        // -------------------------------------------------
        // ui space collision detection
        // --------------------------------------------------
        
        
        
        // 2) reset the quadtree using the bigger area
        expandedBounds.top = globals::uiBounds.getTopLeft().y - buffer;
        expandedBounds.left = globals::uiBounds.getTopLeft().x - buffer;
        expandedBounds.width = globals::uiBounds.getSize().x + 2 * buffer;
        expandedBounds.height = globals::uiBounds.getSize().y + 2 * buffer;
        
        globals::quadtreeUI = Quadtree<entt::entity, decltype(globals::getBoxWorld)>(
            expandedBounds,
            globals::getBoxWorld
        );
        
        // check how many have InactiveTag
        // SPDLOG_DEBUG("Inactive tag in {} entities", globals::getRegistry().view<entity_gamestate_management::InactiveTag>().size());
                
        globals::getRegistry().view<transform::Transform, transform::GameObject, collision::ScreenSpaceCollisionMarker, entity_gamestate_management::StateTag >(entt::exclude<entity_gamestate_management::InactiveTag>)
            .each([&](entt::entity e, auto &transform, auto &go, auto &stateTag){
                if (entity_gamestate_management::active_states_instance().is_active(stateTag) == false) return; // skip collision on inactive entities
                if (!go.state.collisionEnabled) return;
                auto box = globals::getBoxWorld(e);
                
                
                // if this is a scroll pane item, cull against the viewport
                // If it belongs under a pane, test visibility against pane viewport,
                // accounting for scroll offset
                bool include = true;
                auto paneRef = globals::getRegistry().try_get<ui::UIPaneParentRef>(e);
                bool isInScrollPane = paneRef != nullptr;
                // Check if this entity IS the scroll pane itself (not just a child of it)
                // The scroll pane itself should NOT have its position adjusted by scroll offset
                bool isScrollPaneItself = isInScrollPane && paneRef->pane == e;
                if (paneRef && !isScrollPaneItself) {
                    if (paneRef->pane != entt::null && globals::getRegistry().valid(paneRef->pane)) {
                        const auto &scr = globals::getRegistry().get<ui::UIScrollComponent>(paneRef->pane);
                        Rectangle paneR = paneViewport(globals::getRegistry(), paneRef->pane);

                        // shift the element by negative scroll to match render position
                        // if scroll displacement is already applied, avoid double-offsetting
                        float adjustedTop = box.top;
                        if (!go.scrollPaneDisplacement) {
                            adjustedTop = box.top - scr.offset;
                        }
                        Rectangle eltR{ box.left,
                                        adjustedTop,
                                        box.width, box.height };

                        include = rectsOverlap(eltR, paneR);
                    }
                }
                if (isInScrollPane && !isScrollPaneItself && include && expandedBounds.contains(box))
                    globals::quadtreeUI.add(e);
                else if ((!isInScrollPane || isScrollPaneItself) && expandedBounds.contains(box)) {
                    // Add the entity to the quadtree if it is within the expanded bounds
                    // Also add scroll pane entities themselves (they don't need scroll adjustment)
                    globals::quadtreeUI.add(e);
                } ;
            });
            
        // broad phase collision detection
        auto rawUI = globals::quadtreeUI.findAllIntersections();
        
        // Deduplicate & normalize the pairs
        auto pairsUI = dedupePairs(rawUI);

        // Single pass: notify each entity exactly once per partner
        for (auto [a,b] : pairsUI) {
            if (!globals::getRegistry().valid(a) || !globals::getRegistry().valid(b))
                continue;
            
            auto &fA = collisionFilterView.get<collision::CollisionFilter>(a);
            auto &fB = collisionFilterView.get<collision::CollisionFilter>(b);
            // bitwise filter:
            // if (fA.mask != 1 || fB.mask != 1) {
            //     SPDLOG_DEBUG("Collision filter mismatch: A mask {} category {}, B mask {} category {}", 
            //         fA.mask, fA.category, fB.mask, fB.category);
            // }
            if ((fA.mask & fB.category) == 0 || (fB.mask & fA.category) == 0)
                continue; // skip entirely
            
            // SPDLOG_DEBUG("Collision passed for filters: A mask {} category {}, B mask {} category {}", 
                // fA.mask, fA.category, fB.mask, fB.category);


                
            // if (collision::CheckCollisionBetweenTransforms(&globals::getRegistry(), a, b) == false) 
            //     continue;

            // // A → B
            // if (auto *sc = globals::getRegistry().try_get<scripting::ScriptComponent>(a)) {
            //     if (sc->hooks.on_collision.valid())
            //         sc->hooks.on_collision(sc->self, b);
            // }
            // // B → A
            // if (auto *sc = globals::getRegistry().try_get<scripting::ScriptComponent>(b)) {
            //     if (sc->hooks.on_collision.valid())
            //         sc->hooks.on_collision(sc->self, a);
            // }
        }

        // all entities intersecting a region
        
        // auto entitiesAtPoint = transform::FindAllEntitiesAtPoint(
        //     GetScaledMousePosition());
        
        // // SPDLOG_DEBUG("excluding cursor & background room entity from entities at point, showing in bottom to top order");
            
        // // print out the entities at the point
        // for (auto e : entitiesAtPoint) {
        //     if (e == globals::cursor || e == globals::gameWorldContainerEntity) {
        //         // Skip the cursor entity and the game world container entity
        //         continue;
        //     }
        //     // Entity e intersects with the query area
        //     // SPDLOG_DEBUG("Entity {} intersects with query area at ({}, {})", 
        //     //     (int)e, GetScaledMousePosition().x, GetScaledMousePosition().y);
        // }
        
        // Box<float> queryArea = globals::getBox(globals::cursor);
        // // return if cursor not contained in world bounds
        // if (!globals::worldBounds.contains(queryArea)) {
        //     // SPDLOG_DEBUG("Query area is out of bounds: ({}, {})", queryArea.getTopLeft().x, queryArea.getTopLeft().y);
        //     return;
        // }
        // auto results = globals::quadtree.query(queryArea);
        
        // // sort results by layer order
        // std::sort(results.begin(), results.end(), [](entt::entity a, entt::entity b) {
        //     if (globals::getRegistry().any_of<layer::LayerOrderComponent>(a) && globals::getRegistry().any_of<layer::LayerOrderComponent>(b)) {
        //         return globals::getRegistry().get<layer::LayerOrderComponent>(a).zIndex < globals::getRegistry().get<layer::LayerOrderComponent>(b).zIndex;
        //     }
        //     return false; // if either entity does not have LayerOrderComponent, do not sort
        // });
        
        // SPDLOG_DEBUG("Query area intersects with {} entities at ({}, {})", results.size(), queryArea.getTopLeft().x, queryArea.getTopLeft().y);
        // //TODO: need to revise with checkCollisionWithPoint to confirm, also sort by layer order
        // auto point = ::Vector2{queryArea.getTopLeft().x, queryArea.getTopLeft().y};
        // for (auto e : results) {
            
        //     if (e == globals::cursor) {
        //         // Skip the cursor entity itself
        //         continue;
        //     }
            
        //     if (!transform::CheckCollisionWithPoint(&globals::getRegistry(), e, point)) return;
            
        //     // Entity e intersects with the query area
        //     SPDLOG_DEBUG("Entity {} intersects with query area at ({}, {})", 
        //         (int)e, queryArea.getTopLeft().x, queryArea.getTopLeft().y);
        // }

        

    }
    
    // Somewhere at file‐scope:
    static float testValue = 0.0f;
    static bool   tweenScheduled = false;

    auto exposeToLua(sol::state &lua) -> void
    {
        auto &rec = BindingRecorder::instance();
        // 1) InputState usertype
        rec.add_type("layers").doc = "Root table for game layers and their components.";
        lua["layers"] = sol::table(lua, sol::create);
        
        // lua["PhysicsManagerInstance"] = std::ref(*globals::physicsManager);

        for (auto &[name, layerPtr] : s_layers) {
            lua["layers"][name] = layerPtr;
            rec.record_property("layers", {name, "Layer", "Layer for " + name + " elements."});
        }
        
        lua.set_function("GetLayer", &GetLayer);
        rec.record_free_function({""}, {
            "GetLayer",
            "---@param name string",
            "---@return Layer @ Gets the layer pointer by name.",
            true, false
        });
        
        
        lua["SetFollowAnchorForEntity"] = sol::overload(
            [](std::shared_ptr<layer::Layer> layer, entt::entity e) {
                SetFollowAnchorForEntity(layer, e);
            }
        );
        
        lua.set_function("add_layer_shader", &game::add_layer_shader);
        lua.set_function("remove_layer_shader", &game::remove_layer_shader);
        lua.set_function("clear_layer_shaders", &game::clear_layer_shaders);

        //FIXME: seems to be undocumented?
        rec.record_free_function({""}, {
            "add_layer_shader",
            "---@param layer string @ \"background\" | \"sprites\" | \"ui\" | \"final\"",
            "---@param shader string Adds a post-process shader to the given layer.",
            true, false
        });

        rec.record_free_function({""}, {
            "remove_layer_shader",
            "---@param layer string",
            "---@param shader string Removes a shader from that layer.",
            true, false
        });

        rec.record_free_function({""}, {
            "clear_layer_shaders",
            "---@param layer string",
            "Clears all shaders from the layer.",
            true, false
        });
    }
    
    std::shared_ptr<physics::PhysicsWorld> physicsWorld = nullptr;
    
    
//-----------------------------------------------------------------------------
// 1) Worley (cellular) noise
//-----------------------------------------------------------------------------
cpFloat CellularNoise(cpVect pos) {
    static const uint8_t permute[] = { /* 512‐entry table as in ObjC */ 
      151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,30,
      69,142,8,99,37,240,21,10,23,190,6,148,247,120,234,75,0,26,197,62,
      94,252,219,203,117,35,11,32,57,177,33,88,237,149,56,87,174,20,125,
      136,171,168,68,175,74,165,71,134,139,48,27,166,77,146,158,231,83,
      111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,102,143,
      54,65,25,63,161,1,216,80,73,209,76,132,187,208,89,18,169,200,196,
      135,130,116,188,159,86,164,100,109,198,173,186,3,64,52,217,226,250,
      124,123,5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,
      17,182,189,28,42,223,183,170,213,119,248,152,2,44,154,163,70,221,153,
      101,155,167,43,172,9,129,22,39,253,19,98,108,110,79,113,224,232,178,
      185,112,104,218,246,97,228,251,34,242,193,238,210,144,12,191,179,162,
      241,81,51,145,235,249,14,239,107,49,192,214,31,181,199,106,157,184,
      84,204,176,115,121,50,45,127,4,150,254,138,236,205,93,222,114,67,29,
      24,72,243,141,128,195,78,66,215,61,156,180,
      // repeat
      151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,30,
      69,142,8,99,37,240,21,10,23,190,6,148,247,120,234,75,0,26,197,62,
      94,252,219,203,117,35,11,32,57,177,33,88,237,149,56,87,174,20,125,
      136,171,168,68,175,74,165,71,134,139,48,27,166,77,146,158,231,83,
      111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,102,143,
      54,65,25,63,161,1,216,80,73,209,76,132,187,208,89,18,169,200,196,
      135,130,116,188,159,86,164,100,109,198,173,186,3,64,52,217,226,250,
      124,123,5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,
      17,182,189,28,42,223,183,170,213,119,248,152,2,44,154,163,70,221,153,
      101,155,167,43,172,9,129,22,39,253,19,98,108,110,79,113,224,232,178,
      185,112,104,218,246,97,228,251,34,242,193,238,210,144,12,191,179,162,
      241,81,51,145,235,249,14,239,107,49,192,214,31,181,199,106,157,184,
      84,204,176,115,121,50,45,127,4,150,254,138,236,205,93,222,114,67,29,
      24,72,243,141,128,195,78,66,215,61,156,180
    };
    
    cpFloat fx = floorf(pos.x);
    cpFloat fy = floorf(pos.y);
    cpFloat rx = pos.x - fx;
    cpFloat ry = pos.y - fy;
    int    ix = (int)fx & 255;
    int    iy = (int)fy & 255;
    
    cpFloat mindist = INFINITY;
    for(int dy = -1; dy <= 1; ++dy) {
      for(int dx = -1; dx <= 1; ++dx) {
        int cell = permute[permute[ix + dx] + iy + dy];
        int cx   = permute[cell];
        int cy   = permute[cx];
        cpFloat ox = (cpFloat)cx / 255.0f + dx - rx;
        cpFloat oy = (cpFloat)cy / 255.0f + dy - ry;
        mindist   = cpfmin(mindist, ox*ox + oy*oy);
      }
    }
    return mindist;
}

static float clamp01(float v) { return std::clamp(v, 0.0f, 1.0f); }

cpFloat CellularNoiseOctaves(cpVect pos, int octaves) {
    cpFloat v = 0.0f;
    for(int i = 0; i < octaves; ++i){
        cpFloat coef = (cpFloat)(2 << i);
        v += CellularNoise(cpvmult(pos, coef)) / coef;
    }
    return v;
}

// Generates (and returns) a Texture2D whose each texel encodes sampler->sample()
// at the corresponding world‐space position under your Camera2D.
Texture2D GenerateDensityTexture(BlockSampler* sampler, const Camera2D& camera) {
    int w = globals::VIRTUAL_WIDTH;
    int h = globals::VIRTUAL_HEIGHT;

    // Allocate a raw buffer for RGBA8 pixels
    Image img = {
        .data    = malloc(w * h * sizeof(Color)),
        .width   = w,
        .height  = h,
        .mipmaps = 1,
        .format  = PIXELFORMAT_UNCOMPRESSED_R8G8B8A8
    };
    Color* pixels = static_cast<Color*>(img.data);

    // Fill buffer
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            // Map screen pixel → world coordinate
            Vector2 world = GetScreenToWorld2D({ (float)x, (float)y }, camera);

            // Sample your density function (convert to chipmunk coords if needed)
            cpVect p = cpv(world.x, world.y);
            float d  = sampler->sample(p);

            // Gray = density*255
            unsigned char v = (unsigned char)(clamp01(d) * 255.0f);
            pixels[y*w + x] = (Color){ v, v, v, 255 };
        }
    }

    // Upload to GPU
    Texture2D tex = LoadTextureFromImage(img);

    // Free CPU‐side image
    UnloadImage(img);

    return tex;
}

    Texture2D GeneratePointCloudDensityTexture(PointCloudSampler* sampler, const Camera2D& camera) {
        int w = globals::VIRTUAL_WIDTH;
        int h = globals::VIRTUAL_HEIGHT;

        // Allocate RGBA8 buffer
        Image img = {
            .data    = malloc(w * h * sizeof(Color)),
            .width   = w,
            .height  = h,
            .mipmaps = 1,
            .format  = PIXELFORMAT_UNCOMPRESSED_R8G8B8A8
        };
        Color* pixels = static_cast<Color*>(img.data);

        for (int y = 0; y < h; ++y) {
            for (int x = 0; x < w; ++x) {
                // Screen → world
                Vector2 world = GetScreenToWorld2D({ (float)x, (float)y }, camera);
                cpVect  p     = cpv(world.x, world.y);

                // Sample density from the point cloud
                float d = sampler->sample(p);

                unsigned char v = (unsigned char)(clamp01(d) * 255.0f);
                pixels[y*w + x] = (Color){ v, v, v, 255 };
            }
        }

        // GPU upload + cleanup
        Texture2D tex = LoadTextureFromImage(img);
        UnloadImage(img);
        return tex;
    }

    
    Texture2D blockSamplerTexture{}; // texture for the block sampler
    Texture2D pointCloudSamplerTexture{}; // texture for the point cloud sampler

    std::shared_ptr<BasicTileCache> _tileCache = nullptr;

    // perform game-specific initialization here. This makes it easier to find all the initialization code
    // specific to a game project
    auto init() -> void
    {
        static bool subscriptionsInstalled = false;
        if (!subscriptionsInstalled) {
            subscriptionsInstalled = true;
            auto& bus = globals::getEventBus();
            bus.subscribe<events::MouseClicked>([](const events::MouseClicked& ev) {
                entt::entity target = ev.target;
                if (target == entt::null) {
                    auto& state = globals::getInputState();
                    auto& registry = globals::getRegistry();
                    if (registry.valid(state.current_designated_hover_target)) {
                        target = state.current_designated_hover_target;
                    } else if (registry.valid(state.cursor_focused_target)) {
                        target = state.cursor_focused_target;
                    }
                }
                globals::recordMouseClick(ev.position, ev.button, target);
                // Invoke click handler if the target is clickable.
                if (target != entt::null) {
                    auto& registry = globals::getRegistry();
                    if (registry.valid(target) && registry.any_of<transform::GameObject>(target)) {
                        auto& node = registry.get<transform::GameObject>(target);
                        if (node.state.clickEnabled) {
                            transform::HandleClick(&registry, target);
                        }
                    }
                }
                // Update cursor overlay for tile picking/debug visualization.
                globals::getGlobalShaderUniforms().set("tile_grid_overlay", "mouse_position",
                    Vector2{ev.position.x / globals::VIRTUAL_WIDTH, ev.position.y / globals::VIRTUAL_HEIGHT});
            });
            bus.subscribe<events::GameStateChanged>([](const events::GameStateChanged& ev) {
                SPDLOG_INFO("Game state changed: {} -> {}", (int)ev.oldState, (int)ev.newState);
            });
            bus.subscribe<events::KeyPressed>([](const events::KeyPressed& ev) {
                if (ev.keyCode == KEY_P) {
                    // globals::setIsGamePaused(!globals::getIsGamePaused());
                    // SPDLOG_INFO("Pause toggled via event bus: {}", globals::getIsGamePaused());
                } else if (ev.keyCode == KEY_F1) {
                    globals::setUseImGUI(!globals::getUseImGUI());
                    SPDLOG_INFO("ImGui toggled via event bus: {}", globals::getUseImGUI());
                } else if (ev.keyCode == KEY_F2) {
                    globals::setReleaseMode(!globals::getReleaseMode());
                    SPDLOG_INFO("Release mode toggled via event bus: {}", globals::getReleaseMode());
                } else if (ev.keyCode == KEY_F3) {
                    globals::setDrawDebugInfo(!globals::drawDebugInfo);
                    SPDLOG_INFO("Debug draw toggled via event bus: {}", globals::drawDebugInfo);
                } else if (ev.keyCode == KEY_F4) {
                    globals::setDrawPhysicsDebug(!globals::drawPhysicsDebug);
                    SPDLOG_INFO("Physics debug toggled via event bus: {}", globals::drawPhysicsDebug);
                } else if (ev.keyCode == KEY_GRAVE) {
#if ENABLE_IMGUI_CONSOLE
                    gui::showConsole = !gui::showConsole;
                    SPDLOG_INFO("Console toggled via ` (backtick): {}", gui::showConsole);
#else
                    SPDLOG_INFO("Console toggle ignored (ImGui console disabled)");
#endif
                } else if (ev.keyCode == KEY_F10) {
                    // Generate debug report
                    SPDLOG_INFO("F10 pressed - generating debug report");
                    if (crash_reporter::IsEnabled()) {
                        auto report = crash_reporter::CaptureReport("Manual debug report (F10)", true);
                        crash_reporter::SerializeReport(report);
#if defined(__EMSCRIPTEN__)
                        crash_reporter::ShowCaptureNotification("Debug report ready. Press 'Copy' to share.");
#else
                        auto path = crash_reporter::PersistReport(report);
                        if (path) {
                            SPDLOG_INFO("Debug report saved to: {}", *path);
                        }
#endif
                    }
                }
            });
            bus.subscribe<events::UIScaleChanged>([](const events::UIScaleChanged& ev) {
                game::OnUIScaleChanged();
            });
            bus.subscribe<events::UIElementFocused>([](const events::UIElementFocused& ev) {
                globals::setLastUIFocus(ev.element);
                if (ev.element != entt::null) {
                    SPDLOG_DEBUG("UI focus changed to entity {}", static_cast<int>(ev.element));
                } else {
                    SPDLOG_DEBUG("UI focus cleared");
                }
            });
            bus.subscribe<events::UIButtonActivated>([](const events::UIButtonActivated& ev) {
                globals::setLastUIButtonActivated(ev.element);
                SPDLOG_DEBUG("UI button activated on entity {} via button {}", static_cast<int>(ev.element), ev.button);
                // Do not call the callback here; the UI click path already invokes it.
                // This event is for telemetry/observers only to avoid double-invoking actions.
                telemetry::RecordEvent("ui_button_activated",
                                       {{"entity", static_cast<int>(ev.element)},
                                        {"button", ev.button},
                                        {"platform", telemetry::PlatformTag()},
                                        {"build_id", telemetry::BuildId()}});
            });
            bus.subscribe<events::LoadingStageStarted>([](const events::LoadingStageStarted& ev) {
                globals::setLastLoadingStage(ev.stageId, true);
                globals::worldGenCurrentStep = ev.stageId;
                globals::loadingStages[globals::loadingStateIndex++] = ev.stageId + " (start)";
                SPDLOG_INFO("Loading stage started: {}", ev.stageId);
                telemetry::RecordEvent("loading_stage_started",
                                       {{"stage", ev.stageId},
                                        {"platform", telemetry::PlatformTag()},
                                        {"build_id", telemetry::BuildId()}});
            });
            bus.subscribe<events::LoadingStageCompleted>([](const events::LoadingStageCompleted& ev) {
                globals::setLastLoadingStage(ev.stageId, ev.success);
                globals::worldGenCurrentStep = ev.stageId;
                std::string msg = ev.stageId + (ev.success ? " (done)" : " (failed: " + ev.error + ")");
                globals::loadingStages[globals::loadingStateIndex++] = msg;
                globals::getGlobalShaderUniforms().set("loading_progress", "stage",
                    Vector2{static_cast<float>(globals::loadingStateIndex), ev.success ? 1.0f : 0.0f});
                SPDLOG_INFO("Loading stage completed: {} (success={}, error='{}')", ev.stageId, ev.success, ev.error);
                telemetry::RecordEvent("loading_stage_completed",
                                       {{"stage", ev.stageId},
                                        {"success", ev.success},
                                        {"error", ev.error},
                                        {"platform", telemetry::PlatformTag()},
                                        {"build_id", telemetry::BuildId()}});
            });
            bus.subscribe<events::CollisionStarted>([](const events::CollisionStarted& ev) {
                // Update a debug uniform so shaders can react to collisions (e.g., flash).
                globals::getGlobalShaderUniforms().set("collision_flash", "last_hit",
                    Vector2{(float)entt::to_integral(ev.entityA), (float)entt::to_integral(ev.entityB)});
                globals::setLastCollision(ev.entityA, ev.entityB);
                // Provide immediate haptic feedback for collisions.
                globals::getVibration() = std::min(1.0f, globals::getVibration() + 0.5f);
                globals::pushCollisionLog(globals::CollisionNote{
                    ev.entityA,
                    ev.entityB,
                    true,
                    ev.point,
                    main_loop::mainLoop.totaltimeTimer
                });
            });
            bus.subscribe<events::CollisionEnded>([](const events::CollisionEnded& ev) {
                globals::setLastCollision(ev.entityA, ev.entityB);
                globals::pushCollisionLog(globals::CollisionNote{
                    ev.entityA,
                    ev.entityB,
                    false,
                    Vector2{0.0f, 0.0f},
                    main_loop::mainLoop.totaltimeTimer
                });
            });
        }
        
        // // testing
        // auto textTestDef = static_ui_text_system::getTextFromString("[Hello here's a longer test\nNow test this](id=stringID;color=red;background=gray) \nWorld Test\nYo man this [good](color=pink;background=red) eh? [img](uuid=gear.png;scale=0.8;fg=WHITE;shadow=false)\nYeah this be an [image](id=imageID;color=red;background=gray)\n Here's an animation [anim](uuid=idle_animation;scale=0.8;fg=WHITE;shadow=false)");
        
        // // make new uiroot
        
        // auto alertRoot = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::ROOT)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addPadding(0.f)
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .addChild(textTestDef)
        //     .build();
            
        // auto testTextBox = ui::box::Initialize(globals::getRegistry(), {.x = 500, .y = 700}, alertRoot, ui::UIConfig{});
        
        // auto rootUiTextBoxEntity = globals::getRegistry().get<ui::UIBoxComponent>(testTextBox).uiRoot;
        
        
        // static_ui_text_system::TextUIHandle handle;
        
        // auto traverseChildren = [](entt::registry& R, entt::entity e) -> std::vector<entt::entity> {
        //     // Replace this with however you enumerate child UI nodes in your ECS.
        //     // Example:
        //     if (R.valid(e) && R.any_of<transform::GameObject>(e)) {
        //         return R.get<transform::GameObject>(e).orderedChildren;
        //     }
        //     return {};
        // };

        
        // buildIdMapFromRoot(globals::getRegistry(), rootUiTextBoxEntity.value(), handle, traverseChildren);
        
        // // Now you can O(1) fetch & mutate:
        // if (auto e = getTextNode(handle, "stringID"); e != entt::null) {
        //     auto &cfg = globals::getRegistry().get<ui::UIConfig>(e);
        //     cfg.color = util::getColor("LIME");
        //     // mark dirty if your layout/text system needs it
        // }
        
        // // set camera to fill the screen
        // // globals::camera = {0};
        // // globals::camera.zoom = 1;
        // // globals::camera.target = {globals::VIRTUAL_WIDTH / 2.0f, globals::VIRTUAL_HEIGHT / 2.0f};
        // // globals::camera.rotation = 0;
        // // globals::camera.offset = {globals::VIRTUAL_WIDTH / 2.0f, globals::VIRTUAL_HEIGHT / 2.0f};
        
        camera_manager::Create("world_camera", globals::getRegistry());
        auto worldCamera = camera_manager::Get("world_camera");
        worldCamera->SetActualOffset({globals::VIRTUAL_WIDTH / 2.0f, globals::VIRTUAL_HEIGHT / 2.0f});
        worldCamera->SetActualTarget({globals::VIRTUAL_WIDTH / 2.0f, globals::VIRTUAL_HEIGHT / 2.0f});
        worldCamera->SetActualZoom(0.8f);
        worldCamera->SetActualRotation(0.0f);

        sound_system::SetCategoryVolume("ui", 0.8f);

        // ImGui::GetIO().FontGlobalScale = 1.5f; // Adjust the scaling factor as needed

        // reflection for user registered componenets
        ui::util::RegisterMeta();

        // create layer the size of the screen, with a main canvas the same size
        RegisterLayer("background", layer::CreateLayerWithSize(globals::VIRTUAL_WIDTH, globals::VIRTUAL_HEIGHT));
        RegisterLayer("sprites",    layer::CreateLayerWithSize(globals::VIRTUAL_WIDTH, globals::VIRTUAL_HEIGHT));
        RegisterLayer("ui",         layer::CreateLayerWithSize(globals::VIRTUAL_WIDTH, globals::VIRTUAL_HEIGHT));
        RegisterLayer("final",      layer::CreateLayerWithSize(globals::VIRTUAL_WIDTH, globals::VIRTUAL_HEIGHT));

        GetLayer("background")->backgroundColor = util::getColor("BLACK");
        GetLayer("final")->backgroundColor = util::getColor("BLACK");

        for (auto name : { "background", "sprites", "ui", "final" }) {
            AddCanvasToLayer(GetLayer(name), "render_double_buffer",
                            globals::VIRTUAL_WIDTH, globals::VIRTUAL_HEIGHT);
        }

        // set camera to fill the screen
        // globals::camera2D = {0};
        // globals::camera2D.zoom = 1;
        // globals::camera2D.target = {globals::VIRTUAL_WIDTH / 2.0f, globals::VIRTUAL_HEIGHT / 2.0f};
        // globals::camera2D.rotation = 0;
        // globals::camera2D.offset = {globals::VIRTUAL_WIDTH / 2.0f, globals::VIRTUAL_HEIGHT / 2.0f};

        exposeToLua(ai_system::masterStateLua); // so layer values will be saved after initialization
        
        // ai_system::masterStateLua.set_panic([](lua_State* L) -> int {
        //     const char* msg = lua_tostring(L, -1);
        //     luaL_traceback(L, L, msg, 1);
        //     const char* fullTrace = lua_tostring(L, -1);
        //     fprintf(stderr, "[LUAJIT PANIC]\n%s\n", fullTrace ? fullTrace : "(nil)");
        //     return 0;
        // });


        transform::registerDestroyListeners(globals::getRegistry());

        // init physics
        physicsWorld = physics::InitPhysicsWorld(&globals::getRegistry(), 64.0f, 0.0f, 0.f);
        
        physicsWorld->AddCollisionTag(physics::DEFAULT_COLLISION_TAG); // default tag
        physicsWorld->AddCollisionTag("player");
        
        // add to physics manager
        globals::physicsManager->add("world", physicsWorld);
        
        // enable debug draw and step debug
        globals::physicsManager->enableDebugDraw("world", true);
        globals::physicsManager->enableStep("world", true);
        
        // // make test transform entity
        // entt::entity testTransformEntity = transform::CreateOrEmplace(&globals::getRegistry(), globals::gameWorldContainerEntity, 100, 100, 100, 100);
        // globals::getRegistry().emplace_or_replace<PhysicsWorldRef>(testTransformEntity, "world");
        
        // auto &gameObjectTest = globals::getRegistry().get<transform::GameObject>(testTransformEntity);
        // gameObjectTest.state.collisionEnabled = true;
        // gameObjectTest.state.dragEnabled = true;
        // gameObjectTest.state.hoverEnabled = true;
        
        // physics::PhysicsCreateInfo info{};
        // info.shape = physics::ColliderShapeType::Rectangle; // can be Circle, Rectangle, Polygon, etc.
        
        // physics::CreatePhysicsForTransform(globals::getRegistry(), *globals::physicsManager, testTransformEntity, info);
        
        cpSpaceSetDamping(physicsWorld->space,0.1f); // global damping
        
        // physicsWorld->SetDamping(testTransformEntity, 3.5f);
        // physicsWorld->SetAngularDamping(testTransformEntity, 3.0f);
        
        // second entity
        
        // entt::entity testEntity = globals::getRegistry().create();
        
        // physicsWorld->AddCollider(testEntity, "player" /* default tag */, "rectangle", 50, 50, -1, -1, false);
        
        // physicsWorld->SetBodyPosition(testEntity, 600.f, 300.f);

        // physicsWorld->AddScreenBounds(0, 0, globals::VIRTUAL_WIDTH, globals::VIRTUAL_HEIGHT);

        // physicsWorld->SetDamping(testEntity, 3.5f);
        // physicsWorld->SetAngularDamping(testEntity, 3.0f);
        // physicsWorld->AddUprightSpring(testEntity, 4500.0f, 1500.0f);
        // physicsWorld->SetFriction(testEntity, 0.2f);
        // physicsWorld->CreateTopDownController(testEntity);
        
        
        // Apply collision filter via your tag system
        // auto rec = globals::physicsManager->get("world");
        // // rec->w->AddCollisionTag("WORLD"); // default tag
        // auto shape = globals::getRegistry().get<physics::ColliderComponent>(testEntity).shape;
        // rec->w->ApplyCollisionFilter(shape.get(), "WORLD" ); // default tag for testing
        
        // make world collide with world
        // rec->w->EnableCollisionBetween("WORLD", {"WORLD"});



        
        // try using ldtk
        
        // ldtk_loader::LoadProject(util::getRawAssetPathNoUUID("test_features.ldtk"));
        // // ldtk_loader::LoadProject(util::getRawAssetPathNoUUID("Typical_TopDown_example.ldtk"));
        // ldtk_loader::LoadProject(util::getRawAssetPathNoUUID("Typical_2D_platformer_example.ldtk"));
        

        // some things I can do:
        
        /*
        world.SetRestitution(player, 0.8f);   // make it bouncy
world.SetFriction(player, 0.2f);      // make it slippery
world.SetMass(player, 2.0f);          // change its mass at runtime
world.SetBodyType(player, "kinematic");  // switch between static/kinematic/dynamic
world.SetDamping(player, 0.05f);      // velocity damping
world.SetGlobalDamping(0.2f);         // world‑wide damping
        */

        // Register UI element handlers (Strategy pattern for type-specific rendering)
        ui::registerAllHandlers();

        SystemRegistry::global().initAll();

        luaMainInitFunc = ai_system::masterStateLua["main"]["init"];
        luaMainUpdateFunc = ai_system::masterStateLua["main"]["update"];
        luaMainDrawFunc = ai_system::masterStateLua["main"]["draw"];

        if (testing::is_test_mode_enabled()) {
            spdlog::info("[test_mode] Skipping lua main.init");
        } else {
            if (!luaMainInitFunc.valid()) {
                spdlog::error("Lua init function missing on master state");
                assert(false);
            }

            auto initResult = util::safeLuaCall(luaMainInitFunc, "lua main.init");
            if (initResult.isErr()) {
                spdlog::error("Lua init failed: {}", initResult.error());
                assert(false);
            }
        }
        
        
    }
    
    

    auto update(float delta) -> void
    {

        // Process pending save callbacks on main thread
        save_io::process_pending_callbacks();

        // physicsWorld->Update(delta);
        // _tileCache->ensureRect(cpBBNew(0, 0, globals::VIRTUAL_WIDTH, globals::VIRTUAL_HEIGHT));

        camera_manager::UpdateAll(delta);
        
        auto worldCamera = camera_manager::Get("world_camera");
        
        // mouse wheel for zoom
        if (GetMouseWheelMove() > 0) {
            // globals::camera.zoom += 0.1f;
            worldCamera->SetActualZoom(worldCamera->GetActualZoom() + 0.1f);
            if (worldCamera->GetActualZoom() > 3.0f)
                worldCamera->SetActualZoom(3.0f);
        }
        else if (GetMouseWheelMove() < 0) {
            // globals::camera.zoom -= 0.1f;
            worldCamera->SetActualZoom(worldCamera->GetActualZoom() - 0.1f);
            if (worldCamera->GetActualZoom() < 0.2f)
                worldCamera->SetActualZoom(0.2f);
        }
        
        // pan camera based on arrow keys
        if (IsKeyDown(KEY_LEFT)) {
            // globals::camera.target.x -= 200.0f * delta;
            worldCamera->SetActualTarget(
                {worldCamera->GetActualTarget().x - 50, worldCamera->GetActualTarget().y}
            );
        }
        if (IsKeyDown(KEY_RIGHT)) {
            // globals::camera.target.x += 200.0f * delta;
            worldCamera->SetActualTarget(
                {worldCamera->GetActualTarget().x + 50, worldCamera->GetActualTarget().y}
            );
        }
        if (IsKeyDown(KEY_UP)) {
            // globals::camera.target.y -= 200.0f * delta;
            worldCamera->SetActualTarget(
                {worldCamera->GetActualTarget().x, worldCamera->GetActualTarget().y - 50}
            );
        }
        if (IsKeyDown(KEY_DOWN)) {
            // globals::camera.target.y += 200.0f * delta;
            worldCamera->SetActualTarget(
                {worldCamera->GetActualTarget().x, worldCamera->GetActualTarget().y + 50}
            );
        }
        
        if (IsKeyDown(KEY_R)) {
            // jiggle camera rotation
            worldCamera->SetVisualRotation(10);
            
            // spring::pull(worldCamera->GetSpringRotation(), 100);
        }
        
        if (IsKeyDown(KEY_PERIOD)) {
            // show/hide imgui
            globals::setUseImGUI(!globals::getUseImGUI());
        }
        
        if (IsKeyPressed(KEY_TAB)) {
            // fullscreen toggle
            ToggleFullscreen();
        }
        
        // if (IsKeyDown(KEY_S)) {
        //     // shake camera
        //     worldCamera->Shake(10, 2.0f);
        // }
        
        // random chance to set camera target to random location
        // if (Random::get<int>(0, 100) < 5) {
        //     worldCamera->SetActualTarget(
        //         {Random::get<float>(0, globals::VIRTUAL_WIDTH), worldCamera->GetActualTarget().y}
        //     );
        // }
        
        //TODO: remove later
        
        // 1) On mouse‐down:
        // if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
        //     // physicsWorld->StartMouseDrag(GetMouseX(), GetMouseY());
            
        //     // top down controller movement
        //     auto mousePosWorld = camera_manager::Get("world_camera")->GetMouseWorld();
        //     cpBodySetPosition(physicsWorld->controlBody, cpv(mousePosWorld.x, mousePosWorld.y));
        //     // cpBodySetPosition(controlBody, desiredTouchPos);
        // }
            
        // 2) While dragging:
        // if (IsMouseButtonDown(MOUSE_LEFT_BUTTON))
        //     physicsWorld->UpdateMouseDrag(GetMouseX(), GetMouseY());
        // else
        //     physicsWorld->EndMouseDrag();

        // 3) On mouse‐up:
        // if (IsMouseButtonReleased(MOUSE_LEFT_BUTTON))
        //     physicsWorld->EndMouseDrag();

        globals::getMasterCacheEntityToParentCompMap.clear();
        globals::g_springCache.clear();
        
        // tag all objects attached to UI so we don't have to check later
        // globals::getRegistry().clear<ui::ObjectAttachedToUITag>();
        // globals::getRegistry().view<TextSystem::Text>()
        //     .each([](entt::entity e, TextSystem::Text &text) {
        //         // attach tag
        //         if (globals::getRegistry().valid(e) == false) return; // skip invalid entities
        //         globals::getRegistry().emplace_or_replace<ui::ObjectAttachedToUITag>(e);
        //     });
        // globals::getRegistry().view<AnimationQueueComponent>()
        //     .each([](entt::entity e, AnimationQueueComponent &anim) {
        //         if (globals::getRegistry().valid(e) == false) return; // skip invalid entities
        //         // attach tag
        //         globals::getRegistry().emplace_or_replace<ui::ObjectAttachedToUITag>(e);
        //     });
        // globals::getRegistry().view<ui::InventoryGrid>()
        //     .each([](entt::entity e, ui::InventoryGrid &inv) {
        //         // attach tag
        //         if (globals::getRegistry().valid(e) == false) return; // skip invalid entities
        //         globals::getRegistry().emplace_or_replace<ui::ObjectAttachedToUITag>(e);
        //     });
        
        ZONE_SCOPED("game::update"); // custom label
        if (gameStarted == false)
            gameStarted = true;

        if (isGameOver)
            return;

        if (game::isPaused)
            return;

        SystemRegistry::global().updateAll(delta);

        // auto viewUIBox = globals::getRegistry().view<ui::UIBoxComponent>();
        // for (auto e : viewUIBox)
        // {
        //     auto result = ui::box::DebugPrint(globals::getRegistry(), e);
        //     SPDLOG_DEBUG("UIBox {}: {}", (int)e, result);
        // }
            
        {
            ZONE_SCOPED("z layers, particles, shaders update");
            layer::layer_order_system::UpdateLayerZIndexesAsNecessary();

            particle::UpdateParticles(globals::getRegistry(), delta);
            shaders::updateAllShaderUniforms();
        }
        
        {
            ZONE_SCOPED("TextSystem::Update");
            auto textView = globals::getRegistry().view<TextSystem::Text, entity_gamestate_management::StateTag>();
            for (auto e : textView)
            {
                // check if the entity is active
                // PERF: Use view.get instead of registry.get (avoids extra lookup)
                if (!entity_gamestate_management::active_states_instance().is_active(textView.get<entity_gamestate_management::StateTag>(e)))
                    continue; // skip inactive entities
                TextSystem::Functions::updateText(e, delta);
            }
        }

        // update ui components
        // auto viewUI = globals::getRegistry().view<ui::UIBoxComponent>();
        // for (auto e : viewUI)
        // {
        //     ui::box::Move(globals::getRegistry(), e, f);
        // }
        {
            ZONE_SCOPED("Collison quadtree populate Update");
            initAndResolveCollisionEveryFrame();
        }
        

        {

            // void ui::element::Update(entt::registry &registry, entt::entity entity, float dt, ui::UIConfig *uiConfig, transform::Transform *transform, ui::UIElementComponent *uiElement, transform::GameObject *node)

            // static auto group = registry->group<InheritedProperties>(entt::get<Transform, GameObject>);
            // static auto uiGroup = registry.group<UIElementComponent,
            //                                  UIConfig,
            //                                  UIState,
            //                                  transform::GameObject,
            //                                  transform::Transform>();

            ZONE_SCOPED("UIElement Update");
            // static auto uiElementGroup = globals::getRegistry().group
            ui::EnsureUIGroupInitialized(globals::getRegistry());
            ui::globalUIGroup.each([delta](entt::entity e, ui::UIElementComponent &uiElement, ui::UIConfig &uiConfig, ui::UIState &uiState, transform::GameObject &node, transform::Transform &transform) {
                // check if the entity is active
                if (!entity_gamestate_management::active_states_instance().is_active(globals::getRegistry().get<entity_gamestate_management::StateTag>(e)))
                    return ;; // skip inactive entities
                // update the UI element
                ui::element::Update(globals::getRegistry(), e, delta, &uiConfig, &transform, &uiElement, &node);
            });
            // auto viewUIElement = globals::getRegistry().view<ui::UIElementComponent>();
            // for (auto e : viewUIElement)
            // {
            //     ui::element::Update(globals::getRegistry(), e, delta);
            // }
        }
        
        

        // SPDLOG_DEBUG("{}", ui::box::DebugPrint(globals::getRegistry(), uiBox, 0));
        {
            ZONE_SCOPED("lua gc step");

            // Measure GC pause time
            auto gc_start = std::chrono::high_resolution_clock::now();

            // lua garbage collection
            ai_system::masterStateLua.step_gc(4);

            auto gc_end = std::chrono::high_resolution_clock::now();
            auto gc_ms = std::chrono::duration<double, std::milli>(gc_end - gc_start).count();

            // Track GC pause statistics
            game::g_lastGcPauseMs = gc_ms;
            game::g_maxGcPauseMs = std::max(game::g_maxGcPauseMs, gc_ms);

            // Update rolling average
            game::g_gcPauseSampleCount++;
            game::g_avgGcPauseMs = game::g_avgGcPauseMs + (gc_ms - game::g_avgGcPauseMs) / game::g_gcPauseSampleCount;

            // Warn if GC pause exceeds threshold (5ms is noticeable at 60 FPS)
            if (gc_ms > 5.0) {
                SPDLOG_WARN("Long GC pause detected: {:.2f}ms (threshold: 5ms)", gc_ms);
            }
        }
        
        {
            ZONE_SCOPED("lua main update");
            // update lua main script
            if (luaMainUpdateFunc.valid()) {
                auto luaUpdateResult = util::safeLuaCall(luaMainUpdateFunc, "lua main.update", delta);
                if (luaUpdateResult.isErr()) {
                    spdlog::error("Lua update failed: {}", luaUpdateResult.error());
                }
            } else {
                spdlog::error("Lua update function missing on master state");
            }
        }
        
        
        

    
    }
    
    
    



void DrawRectangleRoundedGradientH(Rectangle rec, float roundnessLeft, float roundnessRight, int segments, Color left, Color right)
{
    // Neither side is rounded
    if ((roundnessLeft <= 0.0f && roundnessRight <= 0.0f) || (rec.width < 1) || (rec.height < 1 ))
    {
        DrawRectangleGradientEx(rec, left, left, right, right);
        return;
    }

    if (roundnessLeft  >= 1.0f) roundnessLeft  = 1.0f;
    if (roundnessRight >= 1.0f) roundnessRight = 1.0f;

    // Calculate corner radius both from right and left
    float recSize = rec.width > rec.height ? rec.height : rec.width;
    float radiusLeft  = (recSize*roundnessLeft)/2;
    float radiusRight = (recSize*roundnessRight)/2;

    if (radiusLeft <= 0.0f) radiusLeft = 0.0f;
    if (radiusRight <= 0.0f) radiusRight = 0.0f;

    if (radiusRight <= 0.0f && radiusLeft <= 0.0f) return;

    float stepLength = 90.0f/(float)segments;

    /*
    Diagram Copied here for reference, original at 'DrawRectangleRounded()' source code

          P0____________________P1
          /|                    |\
         /1|          2         |3\
     P7 /__|____________________|__\ P2
       |   |P8                P9|   |
       | 8 |          9         | 4 |
       | __|____________________|__ |
     P6 \  |P11              P10|  / P3
         \7|          6         |5/
          \|____________________|/
          P5                    P4
    */

    // Coordinates of the 12 points also apdated from `DrawRectangleRounded`
    const Vector2 point[12] = {
        // PO, P1, P2
        {(float)rec.x + radiusLeft, rec.y}, {(float)(rec.x + rec.width) - radiusRight, rec.y}, { rec.x + rec.width, (float)rec.y + radiusRight },
        // P3, P4
        {rec.x + rec.width, (float)(rec.y + rec.height) - radiusRight}, {(float)(rec.x + rec.width) - radiusRight, rec.y + rec.height},
        // P5, P6, P7
        {(float)rec.x + radiusLeft, rec.y + rec.height}, { rec.x, (float)(rec.y + rec.height) - radiusLeft}, {rec.x, (float)rec.y + radiusLeft},
        // P8, P9
        {(float)rec.x + radiusLeft, (float)rec.y + radiusLeft}, {(float)(rec.x + rec.width) - radiusRight, (float)rec.y + radiusRight},
        // P10, P11
        {(float)(rec.x + rec.width) - radiusRight, (float)(rec.y + rec.height) - radiusRight}, {(float)rec.x + radiusLeft, (float)(rec.y + rec.height) - radiusLeft}
    };

    const Vector2 centers[4] = { point[8], point[9], point[10], point[11] };
    const float angles[4] = { 180.0f, 270.0f, 0.0f, 90.0f };

#if defined(SUPPORT_QUADS_DRAW_MODE)
    rlSetTexture(GetShapesTexture().id);
    Rectangle shapeRect = GetShapesTextureRectangle();

    rlBegin(RL_QUADS);
        // Draw all the 4 corners: [1] Upper Left Corner, [3] Upper Right Corner, [5] Lower Right Corner, [7] Lower Left Corner
        for (int k = 0; k < 4; ++k)
        {
            Color color;
            float radius;
            if (k == 0) color = left,  radius = radiusLeft;     // [1] Upper Left Corner
            if (k == 1) color = right, radius = radiusRight;    // [3] Upper Right Corner
            if (k == 2) color = right, radius = radiusRight;    // [5] Lower Right Corner
            if (k == 3) color = left,  radius = radiusLeft;     // [7] Lower Left Corner
            float angle = angles[k];
            const Vector2 center = centers[k];

            for (int i = 0; i < segments/2; i++)
            {
                rlColor4ub(color.r, color.g, color.b, color.a);
                rlTexCoord2f(shapeRect.x/texShapes.width, shapeRect.y/texShapes.height);
                rlVertex2f(center.x, center.y);

                rlTexCoord2f((shapeRect.x + shapeRect.width)/texShapes.width, shapeRect.y/texShapes.height);
                rlVertex2f(center.x + cosf(DEG2RAD*(angle + stepLength*2))*radius, center.y + sinf(DEG2RAD*(angle + stepLength*2))*radius);

                rlTexCoord2f((shapeRect.x + shapeRect.width)/texShapes.width, (shapeRect.y + shapeRect.height)/texShapes.height);
                rlVertex2f(center.x + cosf(DEG2RAD*(angle + stepLength))*radius, center.y + sinf(DEG2RAD*(angle + stepLength))*radius);

                rlTexCoord2f(shapeRect.x/texShapes.width, (shapeRect.y + shapeRect.height)/texShapes.height);
                rlVertex2f(center.x + cosf(DEG2RAD*angle)*radius, center.y + sinf(DEG2RAD*angle)*radius);

                angle += (stepLength*2);
            }

            // End one even segments
            if ( segments % 2)
            {
                rlTexCoord2f(shapeRect.x/texShapes.width, shapeRect.y/texShapes.height);
                rlVertex2f(center.x, center.y);

                rlTexCoord2f((shapeRect.x + shapeRect.width)/texShapes.width, (shapeRect.y + shapeRect.height)/texShapes.height);
                rlVertex2f(center.x + cosf(DEG2RAD*(angle + stepLength))*radius, center.y + sinf(DEG2RAD*(angle + stepLength))*radius);

                rlTexCoord2f(shapeRect.x/texShapes.width, (shapeRect.y + shapeRect.height)/texShapes.height);
                rlVertex2f(center.x + cosf(DEG2RAD*angle)*radius, center.y + sinf(DEG2RAD*angle)*radius);

                rlTexCoord2f((shapeRect.x + shapeRect.width)/texShapes.width, shapeRect.y/texShapes.height);
                rlVertex2f(center.x, center.y);
            }
        }

        // Here we use the 'Diagram' to guide ourselves to which point receives what color
        // By choosing the color correctly associated with a pointe the gradient effect
        // will naturally come from OpenGL interpolation

        // [2] Upper Rectangle
        rlColor4ub(left.r, left.g, left.b, left.a);
        rlTexCoord2f(shapeRect.x/texShapes.width, shapeRect.y/texShapes.height);
        rlVertex2f(point[0].x, point[0].y);
        rlTexCoord2f(shapeRect.x/texShapes.width, (shapeRect.y + shapeRect.height)/texShapes.height);
        rlVertex2f(point[8].x, point[8].y);

        rlColor4ub(right.r, right.g, right.b, right.a);
        rlTexCoord2f((shapeRect.x + shapeRect.width)/texShapes.width, (shapeRect.y + shapeRect.height)/texShapes.height);
        rlVertex2f(point[9].x, point[9].y);

        rlColor4ub(right.r, right.g, right.b, right.a);
        rlTexCoord2f((shapeRect.x + shapeRect.width)/texShapes.width, shapeRect.y/texShapes.height);
        rlVertex2f(point[1].x, point[1].y);

        // [4] Left Rectangle
        rlColor4ub(right.r, right.g, right.b, right.a);
        rlTexCoord2f(shapeRect.x/texShapes.width, shapeRect.y/texShapes.height);
        rlVertex2f(point[2].x, point[2].y);
        rlTexCoord2f(shapeRect.x/texShapes.width, (shapeRect.y + shapeRect.height)/texShapes.height);
        rlVertex2f(point[9].x, point[9].y);
        rlTexCoord2f((shapeRect.x + shapeRect.width)/texShapes.width, (shapeRect.y + shapeRect.height)/texShapes.height);
        rlVertex2f(point[10].x, point[10].y);
        rlTexCoord2f((shapeRect.x + shapeRect.width)/texShapes.width, shapeRect.y/texShapes.height);
        rlVertex2f(point[3].x, point[3].y);

        // [6] Bottom Rectangle
        rlColor4ub(left.r, left.g, left.b, left.a);
        rlTexCoord2f(shapeRect.x/texShapes.width, shapeRect.y/texShapes.height);
        rlVertex2f(point[11].x, point[11].y);
        rlTexCoord2f(shapeRect.x/texShapes.width, (shapeRect.y + shapeRect.height)/texShapes.height);
        rlVertex2f(point[5].x, point[5].y);

        rlColor4ub(right.r, right.g, right.b, right.a);
        rlTexCoord2f((shapeRect.x + shapeRect.width)/texShapes.width, (shapeRect.y + shapeRect.height)/texShapes.height);
        rlVertex2f(point[4].x, point[4].y);
        rlTexCoord2f((shapeRect.x + shapeRect.width)/texShapes.width, shapeRect.y/texShapes.height);
        rlVertex2f(point[10].x, point[10].y);

        // [8] left Rectangle
        rlColor4ub(left.r, left.g, left.b, left.a);
        rlTexCoord2f(shapeRect.x/texShapes.width, shapeRect.y/texShapes.height);
        rlVertex2f(point[7].x, point[7].y);
        rlTexCoord2f(shapeRect.x/texShapes.width, (shapeRect.y + shapeRect.height)/texShapes.height);
        rlVertex2f(point[6].x, point[6].y);
        rlTexCoord2f((shapeRect.x + shapeRect.width)/texShapes.width, (shapeRect.y + shapeRect.height)/texShapes.height);
        rlVertex2f(point[11].x, point[11].y);
        rlTexCoord2f((shapeRect.x + shapeRect.width)/texShapes.width, shapeRect.y/texShapes.height);
        rlVertex2f(point[8].x, point[8].y);

        // [9] Middle Rectangle
        rlColor4ub(left.r, left.g, left.b, left.a);
        rlTexCoord2f(shapeRect.x/texShapes.width, shapeRect.y/texShapes.height);
        rlVertex2f(point[8].x, point[8].y);
        rlTexCoord2f(shapeRect.x/texShapes.width, (shapeRect.y + shapeRect.height)/texShapes.height);
        rlVertex2f(point[11].x, point[11].y);

        rlColor4ub(right.r, right.g, right.b, right.a);
        rlTexCoord2f((shapeRect.x + shapeRect.width)/texShapes.width, (shapeRect.y + shapeRect.height)/texShapes.height);
        rlVertex2f(point[10].x, point[10].y);
        rlTexCoord2f((shapeRect.x + shapeRect.width)/texShapes.width, shapeRect.y/texShapes.height);
        rlVertex2f(point[9].x, point[9].y);

    rlEnd();
    rlSetTexture(0);
#else

    // Here we use the 'Diagram' to guide ourselves to which point receives what color
    // By choosing the color correctly associated with a pointe the gradient effect
    // will naturally come from OpenGL interpolation
    // But this time instead of Quad, we think in triangles

    rlBegin(RL_TRIANGLES);
        // Draw all of the 4 corners: [1] Upper Left Corner, [3] Upper Right Corner, [5] Lower Right Corner, [7] Lower Left Corner
        for (int k = 0; k < 4; ++k)
        {
            Color color = { 0 };
            float radius = 0.0f;
            if (k == 0) color = left,  radius = radiusLeft;     // [1] Upper Left Corner
            if (k == 1) color = right, radius = radiusRight;    // [3] Upper Right Corner
            if (k == 2) color = right, radius = radiusRight;    // [5] Lower Right Corner
            if (k == 3) color = left,  radius = radiusLeft;     // [7] Lower Left Corner

            float angle = angles[k];
            const Vector2 center = centers[k];

            for (int i = 0; i < segments; i++)
            {
                rlColor4ub(color.r, color.g, color.b, color.a);
                rlVertex2f(center.x, center.y);
                rlVertex2f(center.x + cosf(DEG2RAD*(angle + stepLength))*radius, center.y + sinf(DEG2RAD*(angle + stepLength))*radius);
                rlVertex2f(center.x + cosf(DEG2RAD*angle)*radius, center.y + sinf(DEG2RAD*angle)*radius);
                angle += stepLength;
            }
        }

        // [2] Upper Rectangle
        rlColor4ub(left.r, left.g, left.b, left.a);
        rlVertex2f(point[0].x, point[0].y);
        rlVertex2f(point[8].x, point[8].y);
        rlColor4ub(right.r, right.g, right.b, right.a);
        rlVertex2f(point[9].x, point[9].y);
        rlVertex2f(point[1].x, point[1].y);
        rlColor4ub(left.r, left.g, left.b, left.a);
        rlVertex2f(point[0].x, point[0].y);
        rlColor4ub(right.r, right.g, right.b, right.a);
        rlVertex2f(point[9].x, point[9].y);

        // [4] Right Rectangle
        rlColor4ub(right.r, right.g, right.b, right.a);
        rlVertex2f(point[9].x, point[9].y);
        rlVertex2f(point[10].x, point[10].y);
        rlVertex2f(point[3].x, point[3].y);
        rlVertex2f(point[2].x, point[2].y);
        rlVertex2f(point[9].x, point[9].y);
        rlVertex2f(point[3].x, point[3].y);

        // [6] Bottom Rectangle
        rlColor4ub(left.r, left.g, left.b, left.a);
        rlVertex2f(point[11].x, point[11].y);
        rlVertex2f(point[5].x, point[5].y);
        rlColor4ub(right.r, right.g, right.b, right.a);
        rlVertex2f(point[4].x, point[4].y);
        rlVertex2f(point[10].x, point[10].y);
        rlColor4ub(left.r, left.g, left.b, left.a);
        rlVertex2f(point[11].x, point[11].y);
        rlColor4ub(right.r, right.g, right.b, right.a);
        rlVertex2f(point[4].x, point[4].y);

        // [8] Left Rectangle
        rlColor4ub(left.r, left.g, left.b, left.a);
        rlVertex2f(point[7].x, point[7].y);
        rlVertex2f(point[6].x, point[6].y);
        rlVertex2f(point[11].x, point[11].y);
        rlVertex2f(point[8].x, point[8].y);
        rlVertex2f(point[7].x, point[7].y);
        rlVertex2f(point[11].x, point[11].y);

        // [9] Middle Rectangle
        rlColor4ub(left.r, left.g, left.b, left.a);
        rlVertex2f(point[8].x, point[8].y);
        rlVertex2f(point[11].x, point[11].y);
        rlColor4ub(right.r, right.g, right.b, right.a);
        rlVertex2f(point[10].x, point[10].y);
        rlVertex2f(point[9].x, point[9].y);
        rlColor4ub(left.r, left.g, left.b, left.a);
        rlVertex2f(point[8].x, point[8].y);
        rlColor4ub(right.r, right.g, right.b, right.a);
        rlVertex2f(point[10].x, point[10].y);
    rlEnd();
#endif
}





void DrawGradientRectRoundedCentered(
    float cx, float cy,
    float width, float height,
    float roundness,
    int segments,
    Color top,
    Color bottom,
    Color, Color) // unused last two color params, for signature compatibility
{
    if (width <= 0.0f || height <= 0.0f) return;

    Rectangle rec = {
        cx - width * 0.5f,
        cy - height * 0.5f,
        width,
        height
    };

    rlPushMatrix();

    // Move to center of rectangle before rotation
    rlTranslatef(cx, cy, 0.0f);

    // Rotate -90° CCW so horizontal gradient becomes vertical (top→bottom)
    rlRotatef(-90.0f, 0.0f, 0.0f, 1.0f);

    // Adjust rectangle to rotated coordinate system (centered again)
    Rectangle rotated = {
        -height * 0.5f,  // new x (since rotated)
        -width * 0.5f,   // new y
        height,          // swapped width/height
        width
    };

    // Reuse existing horizontal version safely
    DrawRectangleRoundedGradientH(rotated, roundness, roundness, segments, top, bottom);

    rlPopMatrix();
}

static std::unordered_map<entt::entity, uint64_t> s_drawAnchorByEntity;


void DrawHollowCircleStencil(Vector2 center, float outerR, float innerR, Color color) {
    
    // DrawEllipse(400, 300, 100, 50, RED);
    // --- 1. Begin stencil workflow ---
    layer::beginStencil();

    // --- 2. Begin outer mask (set stencil = 1) ---
    layer::beginStencilMask();
    // layer::Circle(center.x, center.y, outerR, color);
    // layer::ellipse(center.x, center.y, innerR, innerR, color);
    DrawEllipse(center.x, center.y, outerR, outerR, color);
    rlDrawRenderBatchActive(); // ensure it's flushed before next stencil op
    
    // --- 3. Draw inner circle to erase stencil (set stencil = 0) ---
    glStencilMask(0xFF);
    glStencilFunc(GL_ALWAYS, 0, 0xFF);
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
    glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
    // layer::Circle(center.x, center.y, innerR, color);
    // layer::ellipse(center.x, center.y, innerR, innerR, color);
    DrawEllipse(center.x, center.y, innerR, innerR, color);
    rlDrawRenderBatchActive(); // flush again before switching modes

    // --- 4. End mask, draw visible ring only where stencil == 1 ---
    layer::endStencilMask();
    // DrawCircleV(center, outerR, color);
    DrawEllipse(center.x, center.y, outerR, outerR, color);

    // --- 5. Cleanup ---
    layer::endStencil();
}


    auto draw(float dt) -> void
    {
        ZONE_SCOPED("game::draw"); // custom label
        
        auto background = GetLayer("background");
        auto sprites = GetLayer("sprites");
        auto ui_layer = GetLayer("ui");
        auto finalOutput = GetLayer("final");
        
        
        // detect fullscreen
        #ifdef __APPLE__
        if (IsWindowFullscreen()) {
            int expectedW = GetMonitorWidth(GetCurrentMonitor());
            int expectedH = GetMonitorHeight(GetCurrentMonitor());

            if (GetScreenWidth() != expectedW ||
                GetScreenHeight() != expectedH)
            {
                SetWindowSize(expectedW, expectedH);
            }
        }
        #endif
        
        // letterbox calculations
        const int screenW = GetScreenWidth();
        const int screenH = GetScreenHeight();

        const float scaleX = static_cast<float>(screenW) / static_cast<float>(globals::VIRTUAL_WIDTH);
        const float scaleY = static_cast<float>(screenH) / static_cast<float>(globals::VIRTUAL_HEIGHT);

        // Uniform scale (letterbox)
        const float scale   = std::min(scaleX, scaleY);
        const float outW    = globals::VIRTUAL_WIDTH  * scale;
        const float outH    = globals::VIRTUAL_HEIGHT * scale;
        const float offsetX = (screenW - outW) * 0.5f;
        const float offsetY = (screenH - outH) * 0.5f;
        
        // store the offests for letterbox
        globals::setLetterboxOffsetX(offsetX);
        globals::setLetterboxOffsetY(offsetY);
        globals::setFinalRenderScale(scale);

        // set up layers (needs to happen every frame)
        
        
        {
            ZONE_SCOPED("game::draw-lua draw main script");
            // update lua main script
            if (luaMainDrawFunc.valid()) {
                auto luaDrawResult = util::safeLuaCall(luaMainDrawFunc, "lua main.draw", dt);
                if (luaDrawResult.isErr()) {
                    spdlog::error("Lua draw failed: {}", luaDrawResult.error());
                }
            } else {
                spdlog::error("Lua draw function missing on master state");
            }
        }
        
        auto worldCamera = camera_manager::Get("world_camera");
        


        {
            ZONE_SCOPED("game::draw-UIElement Draw");
            // debug draw ui elements (draw ui boxes, will auto-propogate to children)
            // auto viewUI = globals::getRegistry().view<ui::UIBoxComponent>();
            // for (auto e : viewUI)
            // {
            //     ui::box::Draw(ui_layer, globals::getRegistry(), e);
            // }
            // ui::box::drawAllBoxes(globals::getRegistry(), sprites);
            ui::box::drawAllBoxesShaderEnabled(globals::getRegistry(), sprites);

            // for each ui box, print debug info
            
        }
        
        
        

        // dynamic text
        {
            ZONE_SCOPED("Dynamic Text Draw");
            auto textView = globals::getRegistry().view<TextSystem::Text, entity_gamestate_management::StateTag>(entt::exclude<ui::ObjectAttachedToUITag>);
            for (auto e : textView)
            {
                // check if the entity is active
                if (!entity_gamestate_management::active_states_instance().is_active(textView.get<entity_gamestate_management::StateTag>(e)))
                    continue; // skip inactive entities
                TextSystem::Functions::renderText(e, sprites, true);
            }
        }
        
        // do transform debug drawing
        
        auto view = globals::getRegistry().view<transform::Transform, entity_gamestate_management::StateTag>();
        if (globals::getDrawDebugInfo())
            for (auto e : view)
            {
                // check if the entity is active
                if (!entity_gamestate_management::active_states_instance().is_active(view.get<entity_gamestate_management::StateTag>(e)))
                    continue; // skip inactive entities
                transform::DrawBoundingBoxAndDebugInfo(&globals::getRegistry(), e, sprites);
            }
            
            
            

        {
            ZONE_SCOPED("AnimatedSprite Draw");
            auto spriteView = globals::getRegistry().view<AnimationQueueComponent, entity_gamestate_management::StateTag>(entt::exclude<ui::ObjectAttachedToUITag>);
            for (auto e : spriteView)
            {
                // check if the entity is active
                if (!entity_gamestate_management::active_states_instance().is_active(spriteView.get<entity_gamestate_management::StateTag>(e)))
                    continue; // skip inactive entities
                auto *layerOrder = globals::getRegistry().try_get<layer::LayerOrderComponent>(e);
                auto zIndex = layerOrder ? layerOrder->zIndex : 0;
                bool isScreenSpace = globals::getRegistry().any_of<collision::ScreenSpaceCollisionMarker>(e);
                
                if (!isScreenSpace)
                {
                    // SPDLOG_DEBUG("Drawing animated sprite {} in world space at zIndex {}", (int)e, zIndex);
                }
                
                if (globals::getRegistry().any_of<shader_pipeline::ShaderPipelineComponent>(e))
                {
                    auto cmd = layer::QueueCommand<layer::CmdDrawTransformEntityAnimationPipeline>(sprites, [e](auto* cmd) {
                        cmd->e = e;
                        cmd->registry = &globals::getRegistry();
                    }, zIndex, isScreenSpace ? layer::DrawCommandSpace::Screen : layer::DrawCommandSpace::World);
                    
                    // store the unique ID of the last draw command for this entity
                    // s_drawAnchorByEntity[e] = sprites->commands_ptr->back().uniqueID;
                    
                    
                    
                }
                else
                {
                    layer::QueueCommand<layer::CmdDrawTransformEntityAnimation>(sprites, [e](auto* cmd) {
                        cmd->e = e;
                        cmd->registry = &globals::getRegistry();
                    }, zIndex, isScreenSpace ? layer::DrawCommandSpace::Screen : layer::DrawCommandSpace::World);
                    
                    // store the unique ID of the last draw command for this entity
                    // s_drawAnchorByEntity[e] = sprites->commands_ptr->back().uniqueID;

                }            
            }
        }
        
        {
            // Entities that DO NOT have AnimationQueueComponent, but DO have the local render callback
            auto cbView = globals::getRegistry().view<transform::RenderLocalCallback, entity_gamestate_management::StateTag>(
                entt::exclude<ui::ObjectAttachedToUITag, AnimationQueueComponent>);

            for (auto e : cbView) {
                if (!entity_gamestate_management::active_states_instance()
                        .is_active(cbView.get<entity_gamestate_management::StateTag>(e)))
                    continue;

                auto *layerOrder = globals::getRegistry().try_get<layer::LayerOrderComponent>(e);
                const int zIndex = layerOrder ? layerOrder->zIndex : 0;
                const bool isScreenSpace = globals::getRegistry().any_of<collision::ScreenSpaceCollisionMarker>(e);

                if (globals::getRegistry().any_of<shader_pipeline::ShaderPipelineComponent>(e)) {
                    layer::QueueCommand<layer::CmdDrawTransformEntityAnimationPipeline>(
                        sprites, [e](auto* cmd){ cmd->e = e; cmd->registry = &globals::getRegistry(); },
                        zIndex, isScreenSpace ? layer::DrawCommandSpace::Screen : layer::DrawCommandSpace::World);
                } else {
                    layer::QueueCommand<layer::CmdDrawTransformEntityAnimation>(
                        sprites, [e](auto* cmd){ cmd->e = e; cmd->registry = &globals::getRegistry(); },
                        zIndex, isScreenSpace ? layer::DrawCommandSpace::Screen : layer::DrawCommandSpace::World);
                }
            }
        }

        
        // uiProfiler.Stop();
        
        {
            ZONE_SCOPED("Particle Draw");
            particle::DrawParticles(globals::getRegistry(), sprites);
        }
        
        {
            ZONE_SCOPED("Stencil Masked Particles");
            particle::DrawAllStencilMaskedParticles(globals::getRegistry(), sprites);
        }
        
        {
            ZONE_SCOPED("Tilemap draw");
#if ENABLE_LDTK
            if (ldtk_loader::HasActiveProject() && ldtk_loader::HasActiveLevel() && worldCamera) {
                // simple camera-based culling rectangle (pad to avoid pop-in)
                Rectangle view = ldtk_loader::CameraViewRect(
                    worldCamera->cam,
                    (float)globals::VIRTUAL_WIDTH,
                    (float)globals::VIRTUAL_HEIGHT,
                    64.0f);
                ldtk_loader::DrawAllLayers(sprites, ldtk_loader::GetActiveLevel(), 1.0f, 0, &view);
            }
#else
            (void)worldCamera;
#endif
        }
        
        

        {
            ZONE_SCOPED("LayerCommandsToCanvas Draw");
            {
                ZONE_SCOPED("background layer");
                layer::DrawLayerCommandsToSpecificCanvasApplyAllShaders(background, "main", &worldCamera->cam);

                if (auto it = game::s_layerShaders.find("background"); it != game::s_layerShaders.end())
                    game::run_shader_pipeline(background, it->second);
            }
            
            
            
            {
                ZONE_SCOPED("sprites layer");
                layer::DrawLayerCommandsToSpecificCanvasApplyAllShaders(sprites, "main", &worldCamera->cam);

                if (auto it = game::s_layerShaders.find("sprites"); it != game::s_layerShaders.end())
                    game::run_shader_pipeline(sprites, it->second);
            }
            
            {
                ZONE_SCOPED("ui layer");
                layer::DrawLayerCommandsToSpecificCanvasApplyAllShaders(ui_layer, "main", nullptr);

                if (auto it = game::s_layerShaders.find("ui"); it != game::s_layerShaders.end())
                    game::run_shader_pipeline(ui_layer, it->second);
            }

        }

        {
            ZONE_SCOPED("Draw canvases to other canvases with shaders");

            layer::render_stack_switch_internal::RenderStackGuard guard;
            auto dstIt = finalOutput->canvases.find("main");

            if (dstIt != finalOutput->canvases.end() && guard.push(dstIt->second)) {
                // reset the final buffer once per frame before compositing
                ClearBackground(finalOutput->backgroundColor);

                auto drawCanvas = [](const std::shared_ptr<layer::Layer>& src) {
                    auto srcIt = src->canvases.find("main");
                    if (srcIt == src->canvases.end()) return;

                    const RenderTexture2D& srcCanvas = srcIt->second;
                    DrawTexturePro(
                        srcCanvas.texture,
                        {0, 0, (float)srcCanvas.texture.width, (float)-srcCanvas.texture.height},
                        {0, 0, (float)srcCanvas.texture.width, (float)srcCanvas.texture.height},
                        {0, 0},
                        0.0f,
                        WHITE
                    );
                };

                drawCanvas(background);
                // Use premultiplied alpha blending for layers with transparent backgrounds
                // because drawing with alpha to transparent RT inherently premultiplies
                BeginBlendMode(BLEND_ALPHA_PREMULTIPLY);
                drawCanvas(sprites);
                drawCanvas(ui_layer);
                EndBlendMode();
            }
        }

        {
            ZONE_SCOPED("Apply final shaders");

            if (auto it = game::s_layerShaders.find("final"); it != game::s_layerShaders.end())
                game::run_shader_pipeline(finalOutput, it->second);

            // global fullscreen shaders (your old system)
            game::run_shader_pipeline(finalOutput, game::fullscreenShaders);
        }

        
        
        // layer::LogAllPoolStats(background);
        // layer::LogAllPoolStats(ui_layer);
        // layer::LogAllPoolStats(sprites);
        // layer::LogAllPoolStats(finalOutput);

        // layer::DrawCanvasToCurrentRenderTargetWithTransform(ui_layer, "main", 0, 0, 0, 1, 1, WHITE);

        // layer::DrawCanvasToCurrentRenderTargetWithTransform(sprites, "flash", 0, 0, 0, 1, 1, WHITE);   // render the sprite layer flash canvas to the screen

        {
            ZONE_SCOPED("Final Output Draw to screen");
            // BeginDrawing();

            ClearBackground(BLACK);

            // Draw finalOutput.main → actual screen with letterboxing
            layer::DrawCanvasToCurrentRenderTargetWithTransform(
                finalOutput,
                "main",
                offsetX,         // x on physical screen
                offsetY,         // y on physical screen
                0.0f,            // rotation
                scale,           // scaleX
                scale,           // scaleY
                WHITE,
                "crt"            // or "" if you want CRT only sometimes
            );

            // Ensure ImGui renders to the real backbuffer without any leftover
            // render-target or scissor state from the layered passes.
            if (layer::render_stack_switch_internal::IsActive()) {
                layer::render_stack_switch_internal::ForceClear("ImGui backbuffer reset");
            }
            EndScissorMode();
            
            {
#ifndef __EMSCRIPTEN__
            if (globals::getUseImGUI()) {
                ZONE_SCOPED("Debug UI");
                shaders::ShowShaderEditorUI(globals::getGlobalShaderUniforms());
                ShowDebugUI();
                lua_hot_reload::draw_imgui(ai_system::masterStateLua);
            }

                
#endif
            }
            

            // Display UPS and FPS
            // 
            
            // draw rectangles indicating quad tree dimensions
            if (globals::getDrawDebugInfo()) {
                DrawText(fmt::format("UPS: {} FPS: {}", main_loop::mainLoop.renderedUPS, GetFPS()).c_str(), 10, 10, 20, RED);
                
            }
            
            // -- draw physics world
            
            if (globals::getDrawDebugInfo()) {
                Camera2D debugCam = worldCamera->cam;
                debugCam.offset.x = debugCam.offset.x * scale + offsetX;
                debugCam.offset.y = debugCam.offset.y * scale + offsetY;
                debugCam.zoom *= scale;
                camera_manager::Begin(debugCam); // begin camera mode
                DrawRectangle(0, 0, globals::VIRTUAL_WIDTH, globals::VIRTUAL_HEIGHT, Fade(GREEN, 0.1f));
                DrawText("Screen bounds", 5, 35, 20, GREEN);
                
                // bounds for ui quad tree
                DrawRectangle(globals::uiBounds.left, globals::uiBounds.top, globals::uiBounds.width, globals::uiBounds.height, Fade(BLUE, 0.1f));
                DrawText("UI QuadTree bounds", globals::uiBounds.left + 5, globals::uiBounds.top + 20, 20, BLUE);
                
                // bounds for world quad tree
                DrawRectangle(globals::worldBounds.left, globals::worldBounds.top, globals::worldBounds.width, globals::worldBounds.height, Fade(RED, 0.1f));
                DrawText("World QuadTree bounds", globals::worldBounds.left + 300, globals::worldBounds.top + 20, 20, RED);
                
                camera_manager::End(); // end camera mode 
            }
            
            
            if (globals::getDrawPhysicsDebug()) {
                Camera2D debugCam = worldCamera->cam;
                debugCam.offset.x = debugCam.offset.x * scale + offsetX;
                debugCam.offset.y = debugCam.offset.y * scale + offsetY;
                debugCam.zoom *= scale;
                camera_manager::Begin(debugCam); // begin camera mode for the physics world
                
                
                physics::ChipmunkDemoDefaultDrawImpl(physicsWorld->space);
                physicsWorld->DebugDrawContacts();
                
                
                

                camera_manager::End(); // end camera mode for the physics world
            }
            
            fade_system::draw();
            
            // auto mousePos = globals::GetScaledMousePosition();
            // DrawHollowCircleStencil({mousePos.x, mousePos.y}, 100, 50, YELLOW);

            {
                ZONE_SCOPED("EndDrawing call");
                // EndDrawing();
            }

            // layer::Pop();

            // Reset draw call counter and stats for next frame
            layer::g_drawCallsThisFrame = 0;
            layer::g_drawCallStats.reset();

        }

        // fade
        
        
    }

    void SetFollowAnchorForEntity(std::shared_ptr<layer::Layer> layer, entt::entity e)
    {
        auto it = s_drawAnchorByEntity.find(e);
        if (it == s_drawAnchorByEntity.end()) return;

        auto& cmds = *layer->commands_ptr;
        if (!cmds.empty())
            cmds.back().followAnchor = it->second; // make the newest command follow the leader
    }

    void unload() {
        // unload all layers
        layer::UnloadAllLayers();

        // unload all lua scripts
        ai_system::masterStateLua.collect_garbage();
        
        for (auto& [name, layerPtr] : s_layers) {
            clear_layer_shaders(name);
        }
        ClearLayers();
        
        // destroy all entities
        globals::getRegistry().clear(); // clear all entities in the registry
    }

}
