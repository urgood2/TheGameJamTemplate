
#include <memory>

#include "../util/utilities.hpp"

#include "graphics.hpp"
#include "globals.hpp"

// #include "third_party/tracy-master/public/tracy/Tracy.hpp"

#include "../components/components.hpp"
#include "../components/graphics.hpp"

#include "game.hpp" // game.hpp must be included after components.hpp

#include "gui.hpp"
#include "raymath.h"

#include "../third_party/rlImGui/extras/IconsFontAwesome6.h"
#include "../third_party/rlImGui/imgui_internal.h"

#include "../systems/shaders/shader_system.hpp"
#include "../systems/shaders/shader_pipeline.hpp"
#include "../systems/event/event_system.hpp"
#include "../systems/sound/sound_system.hpp"
#include "../systems/text/textVer2.hpp"
#include "../systems/text/static_ui_text.hpp"
#include "../systems/ui/common_definitions.hpp"
#include "../systems/ui/inventory_ui.hpp"
#include "../systems/localization/localization.hpp"
#include "../systems/collision/broad_phase.hpp"
#include "../systems/collision/Quadtree.h"
#include "../systems/scripting/scripting_functions.hpp"
#include "../systems/scripting/scripting_system.hpp"
#include "../systems/ai/ai_system.hpp"
#include "systems/ldtk_loader/ldtk_combined.hpp"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"
#include "rlgl.h"

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
#include "util/utilities.hpp"

#include "core/globals.hpp"
#include "core/misc_fuctions.hpp"
#include "core/ui_definitions.hpp"

#include "systems/layer/layer.hpp"
#include "systems/layer/layer_optimized.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include "systems/layer/layer_order_system.hpp"
#include "systems/shaders/shader_system.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/input/input_functions.hpp"
#include "systems/ui/ui.hpp"
#include "systems/ui/util.hpp"
#include "systems/timer/timer.hpp"
#include "systems/particles/particle.hpp"
#include "systems/random/random.hpp"
#include "systems/second_order_dynamics/second_order_dynamics.hpp"
#include "systems/fade/fade_system.hpp"

#include "entt/entt.hpp"

#include "third_party/rlImGui/rlImGui.h"

#include "raymath.h"



// AsteroidManager *asteroidManager = nullptr;

// example entity
entt::entity player{entt::null}, player2{entt::null}; // example player entity

// example transform entity (which can be anything)
entt::entity transformEntity{entt::null};
entt::entity childEntity{entt::null};
entt::entity childEntity2{entt::null};
entt::entity childEntity3{entt::null};
entt::entity uiBox{entt::null};
entt::entity hoverPopupUIBox{entt::null};
entt::entity dragPopupUIBox{entt::null};
entt::entity alertUIBox{entt::null};
entt::entity testInventory{entt::null};

// lua function handles
sol::function luaMainInitFunc;
sol::function luaMainUpdateFunc;
sol::function luaMainDrawFunc;


float transitionShaderPositionVar = 0.f;

namespace game
{
    
    std::vector<std::string> fullscreenShaders;

    // make layers to draw to
    std::shared_ptr<layer::Layer> background;  // background
    std::shared_ptr<layer::Layer> sprites;     // sprites
    std::shared_ptr<layer::Layer> ui_layer;    // ui
    std::shared_ptr<layer::Layer> particles; 
    std::shared_ptr<layer::Layer> finalOutput; // final output (for post processing)
    
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

    // camera
    entt::entity cameraRotationSpringEntity;
    entt::entity cameraZoomSpringEntity;
    entt::entity cameraXSpringEntity;
    entt::entity cameraYSpringEntity;

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
        globals::registry.view<transform::Transform, transform::GameObject, entity_gamestate_management::StateTag>(entt::exclude<collision::ScreenSpaceCollisionMarker>)
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

        auto collisionFilterView = globals::registry.view<collision::CollisionFilter>();

        // Single pass: notify each entity exactly once per partner
        for (auto [a,b] : pairs) {
            if (!globals::registry.valid(a) || !globals::registry.valid(b))
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


            if (collision::CheckCollisionBetweenTransforms(&globals::registry, a, b) == false) 
                continue;

            // A → B
            if (auto *sc = globals::registry.try_get<scripting::ScriptComponent>(a)) {
                if (sc->hooks.on_collision.valid())
                    sc->hooks.on_collision(sc->self, b);
            }
            // B → A
            if (auto *sc = globals::registry.try_get<scripting::ScriptComponent>(b)) {
                if (sc->hooks.on_collision.valid())
                    sc->hooks.on_collision(sc->self, a);
            }
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
                
        globals::registry.view<transform::Transform, transform::GameObject, collision::ScreenSpaceCollisionMarker, entity_gamestate_management::StateTag>()
            .each([&](entt::entity e, auto &transform, auto &go, auto &stateTag){
                if (entity_gamestate_management::active_states_instance().is_active(stateTag) == false) return; // skip collision on inactive entities
                if (!go.state.collisionEnabled) return;
                auto box = globals::getBoxWorld(e);
                if (expandedBounds.contains(box)) {
                    // Add the entity to the quadtree if it is within the expanded bounds
                    globals::quadtreeUI.add(e);
                } ;
            });
            
        // broad phase collision detection
        auto rawUI = globals::quadtreeWorld.findAllIntersections();
        
        // Deduplicate & normalize the pairs
        auto pairsUI = dedupePairs(rawUI);

        // Single pass: notify each entity exactly once per partner
        for (auto [a,b] : pairsUI) {
            if (!globals::registry.valid(a) || !globals::registry.valid(b))
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


                
            if (collision::CheckCollisionBetweenTransforms(&globals::registry, a, b) == false) 
                continue;

            // A → B
            if (auto *sc = globals::registry.try_get<scripting::ScriptComponent>(a)) {
                if (sc->hooks.on_collision.valid())
                    sc->hooks.on_collision(sc->self, b);
            }
            // B → A
            if (auto *sc = globals::registry.try_get<scripting::ScriptComponent>(b)) {
                if (sc->hooks.on_collision.valid())
                    sc->hooks.on_collision(sc->self, a);
            }
        }

        // all entities intersecting a region
        
        // auto entitiesAtPoint = transform::FindAllEntitiesAtPoint(
        //     GetMousePosition());
        
        // // SPDLOG_DEBUG("excluding cursor & background room entity from entities at point, showing in bottom to top order");
            
        // // print out the entities at the point
        // for (auto e : entitiesAtPoint) {
        //     if (e == globals::cursor || e == globals::gameWorldContainerEntity) {
        //         // Skip the cursor entity and the game world container entity
        //         continue;
        //     }
        //     // Entity e intersects with the query area
        //     // SPDLOG_DEBUG("Entity {} intersects with query area at ({}, {})", 
        //     //     (int)e, GetMousePosition().x, GetMousePosition().y);
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
        //     if (globals::registry.any_of<layer::LayerOrderComponent>(a) && globals::registry.any_of<layer::LayerOrderComponent>(b)) {
        //         return globals::registry.get<layer::LayerOrderComponent>(a).zIndex < globals::registry.get<layer::LayerOrderComponent>(b).zIndex;
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
            
        //     if (!transform::CheckCollisionWithPoint(&globals::registry, e, point)) return;
            
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


        lua["layers"]["background"] = background;
        lua["layers"]["sprites"] = sprites;
        lua["layers"]["ui_layer"] = ui_layer;
        lua["layers"]["finalOutput"] = finalOutput;
        rec.record_property("layers", {"background", "Layer", "Layer for background elements."});
        rec.record_property("layers", {"sprites", "Layer", "Layer for sprite elements."});
        rec.record_property("layers", {"ui_layer", "Layer", "Layer for UI elements."});
        rec.record_property("layers", {"finalOutput", "Layer", "Layer for final output, used for post-processing effects."});
    }

    // perform game-specific initialization here. This makes it easier to find all the initialization code
    // specific to a game project
    auto init() -> void
    {
            // always make container entity by default
        globals::gameWorldContainerEntity = transform::CreateGameWorldContainerEntity(&globals::registry, 0, 0, GetScreenWidth(), GetScreenHeight());
        auto &gameMapNode = globals::registry.get<transform::GameObject>(globals::gameWorldContainerEntity);
        gameMapNode.debug.debugText = "Map Container";
        
        // set camera to fill the screen
        globals::camera = {0};
        globals::camera.zoom = 1;
        globals::camera.target = {GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f};
        globals::camera.rotation = 0;
        globals::camera.offset = {GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f};


        sound_system::SetCategoryVolume("ui", 0.8f);

        // ImGui::GetIO().FontGlobalScale = 1.5f; // Adjust the scaling factor as needed

        // reflection for user registered componenets
        ui::util::RegisterMeta();

        // create layer the size of the screen, with a main canvas the same size
        background = layer::CreateLayerWithSize(GetScreenWidth(), GetScreenHeight());
        sprites = layer::CreateLayerWithSize(GetScreenWidth(), GetScreenHeight());
        ui_layer = layer::CreateLayerWithSize(GetScreenWidth(), GetScreenHeight());
        finalOutput = layer::CreateLayerWithSize(GetScreenWidth(), GetScreenHeight());
        layer::AddCanvasToLayer(finalOutput, "render_double_buffer", GetScreenWidth(), GetScreenHeight());

        // set camera to fill the screen
        globals::camera2D = {0};
        globals::camera2D.zoom = 1;
        globals::camera2D.target = {GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f};
        globals::camera2D.rotation = 0;
        globals::camera2D.offset = {GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f};

        exposeToLua(ai_system::masterStateLua); // so layer values will be saved after initialization


        transform::registerDestroyListeners(globals::registry);

        SetUpShaderUniforms();

        // init lua main script        
        luaMainInitFunc = ai_system::masterStateLua["main"]["init"];
        luaMainUpdateFunc = ai_system::masterStateLua["main"]["update"];
        luaMainDrawFunc = ai_system::masterStateLua["main"]["draw"];
        
        sol::protected_function_result result = luaMainInitFunc();
        if (!result.valid()) {
            sol::error err = result;
            spdlog::error("Lua init failed: {}", err.what());
            assert(false);
        }
        
    }
    
    

    auto update(float delta) -> void
    {
        
        globals::getMasterCacheEntityToParentCompMap.clear();
        globals::g_springCache.clear();
        
        // tag all objects attached to UI so we don't have to check later
        globals::registry.clear<ui::ObjectAttachedToUITag>();
        globals::registry.view<TextSystem::Text>()
            .each([](entt::entity e, TextSystem::Text &text) {
                // attach tag
                globals::registry.emplace_or_replace<ui::ObjectAttachedToUITag>(e);
            });
        globals::registry.view<AnimationQueueComponent>()
            .each([](entt::entity e, AnimationQueueComponent &anim) {
                // attach tag
                globals::registry.emplace_or_replace<ui::ObjectAttachedToUITag>(e);
            });
        globals::registry.view<ui::InventoryGrid>()
            .each([](entt::entity e, ui::InventoryGrid &inv) {
                // attach tag
                globals::registry.emplace_or_replace<ui::ObjectAttachedToUITag>(e);
            });
        
        // ZoneScopedN("game::update"); // custom label
        if (gameStarted == false)
            gameStarted = true;

        if (isGameOver)
            return;

        if (game::isPaused)
            return;

        // TODO: anything that ha s

        // auto viewUIBox = globals::registry.view<ui::UIBoxComponent>();
        // for (auto e : viewUIBox)
        // {
        //     auto result = ui::box::DebugPrint(globals::registry, e);
        //     SPDLOG_DEBUG("UIBox {}: {}", (int)e, result);
        // }
            
        layer::layer_order_system::UpdateLayerZIndexesAsNecessary();

        particle::UpdateParticles(globals::registry, delta);
        shaders::updateAllShaderUniforms();
        
        {
            // ZoneScopedN("TextSystem::Update");
            auto textView = globals::registry.view<TextSystem::Text, entity_gamestate_management::StateTag>();
            for (auto e : textView)
            {
                // check if the entity is active
                if (!entity_gamestate_management::active_states_instance().is_active(globals::registry.get<entity_gamestate_management::StateTag>(e)))
                    continue; // skip inactive entities
                TextSystem::Functions::updateText(e, delta);
            }
        }

        // update ui components
        // auto viewUI = globals::registry.view<ui::UIBoxComponent>();
        // for (auto e : viewUI)
        // {
        //     ui::box::Move(globals::registry, e, f);
        // }
        {
            // ZoneScopedN("Collison quadtree populate Update");
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

            // ZoneScopedN("UIElement Update");
            // static auto uiElementGroup = globals::registry.group

            ui::globalUIGroup.each([delta](entt::entity e, ui::UIElementComponent &uiElement, ui::UIConfig &uiConfig, ui::UIState &uiState, transform::GameObject &node, transform::Transform &transform) {
                // check if the entity is active
                if (!entity_gamestate_management::active_states_instance().is_active(globals::registry.get<entity_gamestate_management::StateTag>(e)))
                    return ;; // skip inactive entities
                // update the UI element
                ui::element::Update(globals::registry, e, delta, &uiConfig, &transform, &uiElement, &node);
            });
            // auto viewUIElement = globals::registry.view<ui::UIElementComponent>();
            // for (auto e : viewUIElement)
            // {
            //     ui::element::Update(globals::registry, e, delta);
            // }
        }

        // SPDLOG_DEBUG("{}", ui::box::DebugPrint(globals::registry, uiBox, 0));
        
        // lua garbage collection
        ai_system::masterStateLua.step_gc(4); 
        
        // update lua main script
        sol::protected_function_result result = luaMainUpdateFunc(delta);
        if (!result.valid()) {
            sol::error err = result;
            spdlog::error("Lua update failed: {}", err.what());
        }
        
    }

    auto draw(float dt) -> void
    {
        // ZoneScopedN("game::draw"); // custom label
        layer::Begin(); // clear all commands, we add new ones every frame

        // set up layers (needs to happen every frame)
        
        layer::QueueCommand<layer::CmdClearBackground>(background, [](auto* cmd) {
            cmd->color = util::getColor("brick_palette_red_resurrect");
        });
        
        {
            // ZoneScopedN("game::draw-lua draw main script");
            // update lua main script
            sol::protected_function_result result = luaMainDrawFunc(dt);
            if (!result.valid()) {
                sol::error err = result;
                spdlog::error("Lua draw failed: {}", err.what());
            }
        }


        {
            // ZoneScopedN("game::draw-UIElement Draw");
            // debug draw ui elements (draw ui boxes, will auto-propogate to children)
            // auto viewUI = globals::registry.view<ui::UIBoxComponent>();
            // for (auto e : viewUI)
            // {
            //     ui::box::Draw(ui_layer, globals::registry, e);
            // }
            // ui::box::drawAllBoxes(globals::registry, sprites);
            ui::box::drawAllBoxesShaderEnabled(globals::registry, sprites);

            // for each ui box, print debug info
            
        }
        
        
        

        // dynamic text
        {
            // ZoneScopedN("Dynamic Text Draw");
            auto textView = globals::registry.view<TextSystem::Text, entity_gamestate_management::StateTag>();
            for (auto e : textView)
            {
                // check if the entity is active
                if (!entity_gamestate_management::active_states_instance().is_active(textView.get<entity_gamestate_management::StateTag>(e)))
                    continue; // skip inactive entities
                TextSystem::Functions::renderText(e, sprites, true);
            }
        }
        
        // do transform debug drawing
        
        auto view = globals::registry.view<transform::Transform, entity_gamestate_management::StateTag>();
        if (globals::drawDebugInfo)
            for (auto e : view)
            {
                // check if the entity is active
                if (!entity_gamestate_management::active_states_instance().is_active(view.get<entity_gamestate_management::StateTag>(e)))
                    continue; // skip inactive entities
                transform::DrawBoundingBoxAndDebugInfo(&globals::registry, e, sprites);
            }
    

        {
            // ZoneScopedN("AnimatedSprite Draw");
            auto spriteView = globals::registry.view<AnimationQueueComponent, entity_gamestate_management::StateTag>();
            for (auto e : spriteView)
            {
                // check if the entity is active
                if (!entity_gamestate_management::active_states_instance().is_active(spriteView.get<entity_gamestate_management::StateTag>(e)))
                    continue; // skip inactive entities
                auto *layerOrder = globals::registry.try_get<layer::LayerOrderComponent>(e);
                auto zIndex = layerOrder ? layerOrder->zIndex : 0;
                bool isScreenSpace = globals::registry.any_of<collision::ScreenSpaceCollisionMarker>(e);
                
                if (!isScreenSpace)
                {
                    SPDLOG_DEBUG("Drawing animated sprite {} in world space at zIndex {}", (int)e, zIndex);
                }
                
                if (globals::registry.any_of<shader_pipeline::ShaderPipelineComponent>(e))
                {
                    layer::QueueCommand<layer::CmdDrawTransformEntityAnimationPipeline>(sprites, [e](auto* cmd) {
                        cmd->e = e;
                        cmd->registry = &globals::registry;
                    }, zIndex, isScreenSpace ? layer::DrawCommandSpace::Screen : layer::DrawCommandSpace::World);
                }
                else
                {
                    layer::QueueCommand<layer::CmdDrawTransformEntityAnimation>(sprites, [e](auto* cmd) {
                        cmd->e = e;
                        cmd->registry = &globals::registry;
                    }, zIndex, isScreenSpace ? layer::DrawCommandSpace::Screen : layer::DrawCommandSpace::World);
                }            
            }
        }
        
        
        // uiProfiler.Stop();
        
        {
            // ZoneScopedN("Particle Draw");
            particle::DrawParticles(globals::registry, sprites);
        }

        {
            // ZoneScopedN("LayerCommandsToCanvas Draw");
            {
                // ZoneScopedN("background layer commands");
                layer::DrawLayerCommandsToSpecificCanvasApplyAllShaders(background, "main", &globals::camera);  // render the background layer commands to its main canvas
            }
            
            
            
            {
                // ZoneScopedN("sprites layer commands");
                layer::DrawLayerCommandsToSpecificCanvasApplyAllShaders(sprites, "main", &globals::camera);     // render the sprite layer commands to its main canvas
            }
            
            {
                
                // ZoneScopedN("ui layer commands");
                layer::DrawLayerCommandsToSpecificCanvasApplyAllShaders(ui_layer, "main", nullptr);    // render the ui layer commands to its main canvas
            }
            
            {
                // ZoneScopedN("final output layer commands");
                layer::DrawLayerCommandsToSpecificCanvasApplyAllShaders(finalOutput, "main", nullptr); // render the final output layer commands to its main canvas
            }
            

            // #ifdef __EMSCRIPTEN__
            // rlDrawRenderBatchActive(); // Emscripten -- keep batch size down
            // #endif
            
            
            
            
            
            layer::Push(&globals::camera2D);

            
            // 4. Render bg main, then sprite flash to the screen (if this was a different type of shader which could be overlapped, you could do that too)

            // layer::DrawCanvasToCurrentRenderTargetWithTransform(background, "main", 0, 0, 0, 1, 1, WHITE, peaches); // render the background layer main canvas to the screen
            // layer::DrawCanvasOntoOtherLayer(background, "main", finalOutput, "main", 0, 0, 0, 1, 1, WHITE); // render the background layer main canvas to the screen
            
            {
                // ZoneScopedN("Draw canvases to other canvases with shaders");
                // layer::DrawCanvasOntoOtherLayerWithShader(background, "main", finalOutput, "main", 0, 0, 0, 1, 1, WHITE, "outer_space_donuts_bg"); // render the background layer main canvas to the screen

                
                layer::DrawCanvasOntoOtherLayer(ui_layer, "main", finalOutput, "main", 0, 0, 0, 1, 1, WHITE); // render the ui layer main canvas to the screen
                
                layer::DrawCanvasOntoOtherLayer(sprites, "main", finalOutput, "main", 0, 0, 0, 1, 1, WHITE); // render the sprite layer main canvas to the screen
                




                // #ifdef __EMSCRIPTEN__
                // rlDrawRenderBatchActive(); // Emscripten -- keep batch size down
                // #endif
            }
        }

        
        // debug memory leak
        
        
        // layer::LogAllPoolStats(background);
        // layer::LogAllPoolStats(ui_layer);
        // layer::LogAllPoolStats(sprites);
        // layer::LogAllPoolStats(finalOutput);

        // layer::DrawCanvasToCurrentRenderTargetWithTransform(ui_layer, "main", 0, 0, 0, 1, 1, WHITE);

        // layer::DrawCanvasToCurrentRenderTargetWithTransform(sprites, "flash", 0, 0, 0, 1, 1, WHITE);   // render the sprite layer flash canvas to the screen

        {
            // ZoneScopedN("Final Output Draw to screen");
            BeginDrawing();

            // clear screen
            ClearBackground(BLACK);
            
            { // build final output layer
                // ZoneScopedN("Draw canvas to render target (screen)");
                layer::DrawCanvasToCurrentRenderTargetWithTransform(finalOutput, "main", 0, 0, 0, 1, 1, WHITE, "crt"); // render the final output layer main canvas to the screen
                
                
                
            }
            
            {
                std::string srcName = "main";
                std::string dstName = "render_double_buffer";

                for (auto &shaderName : fullscreenShaders) {
                    // draw src → dst through shaderName
                    layer::DrawCanvasOntoOtherLayerWithShader(
                        finalOutput,     // src layer
                        srcName,         // src canvas
                        finalOutput,     // dst layer (same)
                        dstName,         // dst canvas
                        0, 0, 0, 1, 1,   // x, y, rotation, scaleX, scaleY
                        WHITE,
                        shaderName
                    );

                    // swap for next pass
                    std::swap(srcName, dstName);
                }

                // after the loop, `srcName` holds the fully-composited result.
                // If it isn’t already “main”, copy it back with no shader:
                if (srcName != "main") {
                    layer::DrawCanvasOntoOtherLayer(
                        finalOutput,
                        srcName,
                        finalOutput,
                        "main",
                        0, 0, 0, 1, 1,
                        WHITE
                    );
                }
                
                // Now, `finalOutput` has the final composited result in its “main” canvas. Draw it to the screen:
                layer::DrawCanvasToCurrentRenderTargetWithTransform(
                    finalOutput, "main", 
                    0, 0, 0, 1, 1, WHITE, "crt"
                );
            }
            
            {
                // ZoneScopedN("Debug UI");
                rlImGuiBegin(); // Required: starts ImGui frame

                shaders::ShowShaderEditorUI(globals::globalShaderUniforms);
                ShowDebugUI();

                rlImGuiEnd(); // Required: renders ImGui on top of Raylib
            }
            

            // Display UPS and FPS
            // DrawText(fmt::format("UPS: {} FPS: {}", main_loop::mainLoop.renderedUPS, GetFPS()).c_str(), 10, 10, 20, RED);

            fade_system::draw();

            {
                // ZoneScopedN("EndDrawing call");
                EndDrawing();
            }

            layer::Pop();

            // BeginMode2D(globals::camera2D);

            // EndMode2D();

            layer::End();
        }

        // fade
    }


    void unload() {
        // unload all layers
        layer::UnloadAllLayers();

        // unload all lua scripts
        ai_system::masterStateLua.collect_garbage();
        
        // destroy all entities
        globals::registry.clear(); // clear all entities in the registry
    }

}