
#include <memory>

#include "../util/utilities.hpp"

#include "graphics.hpp"
#include "globals.hpp"

// #include "third_party/tracy-master/public/tracy/Tracy.hpp"

#include "../components/components.hpp"
#include "../components/graphics.hpp"

#include "game.hpp" // game.hpp must be included after components.hpp

#include "gui.hpp"
#include "raylib.h"
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
#include "spdlog/spdlog.h"
#include "systems/camera/camera_manager.hpp"
#include "systems/ldtk_loader/ldtk_combined.hpp"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"
#include "rlgl.h"
#include "systems/physics/physics_world.hpp"
#include "systems/chipmunk_objectivec/ChipmunkAutogeometry.hpp"
#include "systems/chipmunk_objectivec/ChipmunkTileCache.hpp"
#include "systems/chipmunk_objectivec/ChipmunkPointCloudSampler.hpp"
#include "systems/spring/spring.hpp"
#include "third_party/chipmunk/include/chipmunk/chipmunk_types.h"
#include "third_party/chipmunk/include/chipmunk/cpBB.h"
#include "systems/uuid/uuid.hpp"
#include "systems/composable_mechanics/bootstrap.hpp"
#include "systems/composable_mechanics/ability.hpp"

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
    int w = GetScreenWidth();
    int h = GetScreenHeight();

    // Allocate a raw buffer for RGBA8 pixels
    Image img = {
        .data    = malloc(w * h * sizeof(Color)),
        .width   = w,
        .height  = h,
        .mipmaps = 1,
        .format  = PIXELFORMAT_UNCOMPRESSED_R8G8B8A8
    };
    Color* pixels = (Color*)img.data;

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
        int w = GetScreenWidth();
        int h = GetScreenHeight();

        // Allocate RGBA8 buffer
        Image img = {
            .data    = malloc(w * h * sizeof(Color)),
            .width   = w,
            .height  = h,
            .mipmaps = 1,
            .format  = PIXELFORMAT_UNCOMPRESSED_R8G8B8A8
        };
        Color* pixels = (Color*)img.data;

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
            // always make container entity by default
        globals::gameWorldContainerEntity = transform::CreateGameWorldContainerEntity(&globals::registry, 0, 0, GetScreenWidth(), GetScreenHeight());
        auto &gameMapNode = globals::registry.get<transform::GameObject>(globals::gameWorldContainerEntity);
        gameMapNode.debug.debugText = "Map Container";
        
        // set camera to fill the screen
        // globals::camera = {0};
        // globals::camera.zoom = 1;
        // globals::camera.target = {GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f};
        // globals::camera.rotation = 0;
        // globals::camera.offset = {GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f};
        
        camera_manager::Create("world_camera", globals::registry);
        auto worldCamera = camera_manager::Get("world_camera");
        worldCamera->SetActualOffset({GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f});
        worldCamera->SetActualTarget({GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f});
        worldCamera->SetActualZoom(1.0f);
        worldCamera->SetActualRotation(0.0f);

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
        // globals::camera2D = {0};
        // globals::camera2D.zoom = 1;
        // globals::camera2D.target = {GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f};
        // globals::camera2D.rotation = 0;
        // globals::camera2D.offset = {GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f};

        exposeToLua(ai_system::masterStateLua); // so layer values will be saved after initialization


        transform::registerDestroyListeners(globals::registry);

        SetUpShaderUniforms();
        
        // init physics
        physicsWorld = physics::InitPhysicsWorld(&globals::registry, 64.0f, 0.0f, 0.f);
        
        entt::entity testEntity = globals::registry.create();
        
        physicsWorld->AddCollider(testEntity, "player", "rectangle", 50, 50, -1, -1, false);
        
        physicsWorld->SetBodyPosition(testEntity, 600.f, 300.f);

        physicsWorld->AddScreenBounds(0, 0, GetScreenWidth(), GetScreenHeight());

        physicsWorld->SetDamping(testEntity, 3.5f);
        physicsWorld->SetAngularDamping(testEntity, 3.0f);
        physicsWorld->AddUprightSpring(testEntity, 4500.0f, 1500.0f);
        physicsWorld->SetFriction(testEntity, 0.2f);
        physicsWorld->CreateTopDownController(testEntity);
        
        static PointCloudSampler                      _pointCloud(32.0f);
        static std::unique_ptr<BlockSampler>         _sampler;
        
        static cpVect                                 _randomOffset;
        
        static std::shared_ptr<ChipmunkSpace> physicsSpace = std::make_shared<ChipmunkSpace>(physicsWorld->space);
        static auto sampler = std::make_unique<BlockSampler>([](cpVect pos){
        // 2 octaves of worley + pointCloud sampling
        cpFloat noise = CellularNoiseOctaves(cpvadd(pos, _randomOffset) * (1.0f/300.0f), 2);
        return cpfmin(2.8f * noise, 1.0f) * _pointCloud.sample(pos);
        });
        // BasicTileCache(_sampler.get(), ChipmunkSpace::SpaceFromCPSpace(physicsWorld->space), 128.0f, 8, 64);
        _tileCache = std::make_shared<BasicTileCache>(
            sampler.get(),
            physicsSpace.get(),
            128.0f, // tile size
            8,      // tile margin
            500      // max tiles
        );
        
        
        // pick a random offset once
        _randomOffset = cpvmult(
        cpv((cpFloat)rand()/RAND_MAX, (cpFloat)rand()/RAND_MAX),
        10000.0f
        );
        
        // configure terrain segments
        _tileCache->segmentRadius     = 2.0f;
        _tileCache->segmentFriction   = 0.7f;
        _tileCache->segmentElasticity = 0.3f;

        
        //TODO: test CreateTilemapColliders
        // original row‑major map (6 rows, 8 cols)
        /// 0 = empty, 1 = solid
        // std::vector<std::vector<bool>> rowMajor = {
        //     {0,0,0,0,0,0,0,0},
        //     {0,1,1,1,1,1,1,0},
        //     {0,1,0,0,0,0,1,0},
        //     {0,1,0,1,1,0,1,0},
        //     {0,1,0,0,0,0,1,0},
        //     {0,1,1,1,1,1,1,0},
        // };

        // transpose → colMajor[x][y]
        // std::vector<std::vector<bool>> sampleMap(8, std::vector<bool>(6));
        // for(int y = 0; y < 6; y++){
        //     for(int x = 0; x < 8; x++){
        //         sampleMap[x][y] = rowMajor[y][x];
        //     }
        // }

        // now width = 8, height = 6 as expected
        // physicsWorld->CreateTilemapColliders(sampleMap, 100.0f, 5.0f);
        
        // Assuming 'camera' is your Camera2D…
        Vector2 topLeft     = GetScreenToWorld2D({ 0, 0 },            camera_manager::Get("world_camera")->cam);
        Vector2 bottomRight = GetScreenToWorld2D({ (float)GetScreenWidth(),
        (float)GetScreenHeight() }, camera_manager::Get("world_camera")->cam);

        
        // Now topLeft.y < bottomRight.y
        // cpBB viewBB = cpBBNew(
        //     topLeft.x,      // minX
        //     topLeft.y,      // minY  ← the smaller Y
        //     bottomRight.x,  // maxX
        //     bottomRight.y   // maxY  ← the larger Y
        // );


        // _tileCache->ensureRect(viewBB);
        
        // 1) Convert those Raylib-world (px,Y-down) points → Chipmunk-space (units,Y-up)
        // cpVect physTL = physics::raylibToChipmunkCoords(topLeft);
        // cpVect physBR = physics::raylibToChipmunkCoords(bottomRight);
        
        cpVect physTL = cpv((cpFloat)topLeft.x, (cpFloat)topLeft.y);
        cpVect physBR = cpv((cpFloat)bottomRight.x, (cpFloat)bottomRight.y);

        // 2) Ensure we supply min / max in each axis
        cpFloat minX = fmin(physTL.x, physBR.x);
        cpFloat maxX = fmax(physTL.x, physBR.x);
        cpFloat minY = fmin(physTL.y, physBR.y);
        cpFloat maxY = fmax(physTL.y, physBR.y);

        // 3) Build the BB in physics‐space
        cpBB viewBB = cpBBNew(minX, minY, maxX, maxY);

        // 4) Query your tile-cache in physics units
        _tileCache->ensureRect(viewBB);
        
        // generate a texture for the block sampler
        blockSamplerTexture = GenerateDensityTexture(sampler.get(), camera_manager::Get("world_camera")->cam);
        pointCloudSamplerTexture = GeneratePointCloudDensityTexture(&_pointCloud, camera_manager::Get("world_camera")->cam);
        
        // After your ensureRect call, do:
        // for(CachedTile* t = _tileCache->_cacheTail; t; t = t->next) {
        //     spdlog::info("CachedTile: l={} b={} r={} t={}",
        //                 t->bb.l, t->bb.b,
        //                 t->bb.r, t->bb.t);
        // }
        cpSpatialIndexEach(
            _tileCache->_tileIndex,        // your cpSpatialIndex*
            +[](void *obj, void *){
                auto *tile = static_cast<CachedTile*>(obj);
                spdlog::info("CACHED TILE: l={:.2f}, b={:.2f}, r={:.2f}, t={:.2f}",
                            tile->bb.l, tile->bb.b,
                            tile->bb.r, tile->bb.t);
            },
            nullptr                         // no extra userData needed
        );


        
        auto debugTile = _tileCache->GetTileAt(0, 0);
        
        for (auto &shape : debugTile->shapes) {
            auto boundingBox = shape->bb();
            SPDLOG_DEBUG("Tile at (0, 0) has shape with bounding box: ({}, {}) to ({}, {})",
                boundingBox.l, boundingBox.b, boundingBox.r, boundingBox.t);
        }
        // _tileCache->ensureRect(cpBBNew(0, 0, GetScreenWidth(), GetScreenHeight()));
        
        
        // try using ldtk
        
        ldtk_loader::LoadProject(util::getRawAssetPathNoUUID("test_features.ldtk"));
        
        
        

        // some things I can do:
        
        /*
        world.SetRestitution(player, 0.8f);   // make it bouncy
world.SetFriction(player, 0.2f);      // make it slippery
world.SetMass(player, 2.0f);          // change its mass at runtime
world.SetBodyType(player, "kinematic");  // switch between static/kinematic/dynamic
world.SetDamping(player, 0.05f);      // velocity damping
world.SetGlobalDamping(0.2f);         // world‑wide damping
        */

        // init                                  lua main script        
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
        physicsWorld->Update(delta);
        // _tileCache->ensureRect(cpBBNew(0, 0, GetScreenWidth(), GetScreenHeight()));
        
        camera_manager::UpdateAll(delta);
        
        auto worldCamera = camera_manager::Get("world_camera");
        
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
        
        if (IsKeyDown(KEY_S)) {
            // shake camera
            worldCamera->Shake(10, 2.0f);
        }
        
        //TODO: remove later
        
        // 1) On mouse‐down:
        if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
            // physicsWorld->StartMouseDrag(GetMouseX(), GetMouseY());
            
            // top down controller movement
            auto mousePosWorld = camera_manager::Get("world_camera")->GetMouseWorld();
            cpBodySetPosition(physicsWorld->controlBody, cpv(mousePosWorld.x, mousePosWorld.y));
            // cpBodySetPosition(controlBody, desiredTouchPos);
        }
            
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
        // globals::registry.clear<ui::ObjectAttachedToUITag>();
        // globals::registry.view<TextSystem::Text>()
        //     .each([](entt::entity e, TextSystem::Text &text) {
        //         // attach tag
        //         if (globals::registry.valid(e) == false) return; // skip invalid entities
        //         globals::registry.emplace_or_replace<ui::ObjectAttachedToUITag>(e);
        //     });
        // globals::registry.view<AnimationQueueComponent>()
        //     .each([](entt::entity e, AnimationQueueComponent &anim) {
        //         if (globals::registry.valid(e) == false) return; // skip invalid entities
        //         // attach tag
        //         globals::registry.emplace_or_replace<ui::ObjectAttachedToUITag>(e);
        //     });
        // globals::registry.view<ui::InventoryGrid>()
        //     .each([](entt::entity e, ui::InventoryGrid &inv) {
        //         // attach tag
        //         if (globals::registry.valid(e) == false) return; // skip invalid entities
        //         globals::registry.emplace_or_replace<ui::ObjectAttachedToUITag>(e);
        //     });
        
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
    
    // Draws an animated dashed line between 'start' and 'end'.
// 'dashLength' and 'gapLength' define the pattern in world units.
// 'phase' shifts the pattern along the line (advance it by phase units).
// 'thickness' is the line width.
// 'color' is the line color.
auto DrawDashedLine(const Vector2 &start,
                    const Vector2 &end,
                    float dashLength,
                    float gapLength,
                    float phase,
                    float thickness,
                    Color color) -> void
{
    const float dx = end.x - start.x;
    const float dy = end.y - start.y;
    const float length = std::sqrt(dx*dx + dy*dy);
    if (length <= 0.0f) return;

    // Normalize direction
    const float dirX = dx / length;
    const float dirY = dy / length;

    const float pattern = dashLength + gapLength;
    phase = std::fmod(phase, pattern);

    // Start at -phase so we shift the dashes forward
    float pos = -phase;
    while (pos < length)
    {
        float segStart = (pos < 0) ? 0 : pos;
        float segEnd   = (pos + dashLength > length) ? length : pos + dashLength;

        if (segEnd > 0.0f)
        {
            Vector2 p1 = { start.x + dirX * segStart,
                           start.y + dirY * segStart };
            Vector2 p2 = { start.x + dirX * segEnd,
                           start.y + dirY * segEnd };
            DrawLineEx(p1, p2, thickness, color);
        }
        pos += pattern;
    }
}

static constexpr float EPSILON_SEAM = 1e-4f;   
// Draw a dashed rectangle (optionally rounded).
// rec        : The rectangle area.
// dashLength : Length of each dash (in pixels).
// gapLength  : Length of each gap between dashes.
// phase      : Shift along the perimeter (in pixels).
// radius     : Corner radius. If <= 0, corners are sharp.
// segments   : Resolution for approximating curved dashes (full-circle subdivision).
// thickness  : Line thickness.
// color      : Line color.

void DrawDashedPolylineLoop(const std::vector<Vector2>& pts,
                            const std::vector<float>& cum,
                            float dashLen,
                            float gapLen,
                            float phase,
                            float thickness,
                            Color color)
{
    float total = cum.back();
    float pattern = dashLen + gapLen;

    // normalize phase into [0,pattern)
    phase = std::fmod(phase, pattern);
    if (phase < 0) phase += pattern;

    auto EvalPos = [&](float dist) {
        // wrap into [0,total)
        dist = std::fmod(dist, total);
        if (dist < 0) dist += total;
        // binary-search segment
        auto it = std::upper_bound(cum.begin(), cum.end(), dist);
        int idx = std::clamp(int(it - cum.begin()) - 1, 0, (int)pts.size()-1);
        float local = (dist - cum[idx]) / (cum[idx+1] - cum[idx]);
        Vector2 A = pts[idx];
        Vector2 B = pts[ (idx+1) % pts.size() ];
        return Vector2{ A.x + (B.x-A.x)*local,
                        A.y + (B.y-A.y)*local };
    };

    // step the dash window
    for (float t = -phase; t < total; t += pattern) {
        float start = t;
        float end   = t + dashLen;

        if (end <= total) {
            Vector2 P0 = EvalPos(start), P1 = EvalPos(end);
            DrawLineEx(P0, P1, thickness, color);
        } else {
            // two-part dash: tail + head
            Vector2 P0 = EvalPos(start);
            Vector2 Pmid = EvalPos(total);
            DrawLineEx(P0, Pmid, thickness, color);
            Vector2 P1 = EvalPos(end);
            Vector2 PheadStart = EvalPos(0.0f);
            DrawLineEx(PheadStart, P1, thickness, color);
        }
    }
}

static std::vector<Vector2> BuildPerimeter(const Rectangle& rec, float radius, int arcSteps) {
    std::vector<Vector2> pts;
    pts.reserve(4*arcSteps + 8);

    float x = rec.x, y = rec.y, w = rec.width, h = rec.height;
    float R = std::clamp(radius, 0.0f, std::min(w,h)*0.5f);

    // 1. Top edge
    pts.push_back({ x+R,       y });
    pts.push_back({ x+w-R,     y });

    // 2. Top-right quarter-arc (270°→360°), EXCLUDE both end-points
    for (int i = 1; i < arcSteps; ++i) {
        float a = 1.5f*PI + (PI/2)*(i/(float)arcSteps);
        pts.push_back({
            x + w - R + std::cos(a)*R,
            y +     R + std::sin(a)*R
        });
    }

    // 3. Right edge
    pts.push_back({ x+w,       y+R });
    pts.push_back({ x+w,       y+h-R });

    // 4. Bottom-right quarter-arc (0°→90°)
    for (int i = 1; i < arcSteps; ++i) {
        float a = 0.0f     + (PI/2)*(i/(float)arcSteps);
        pts.push_back({
            x + w - R + std::cos(a)*R,
            y + h - R + std::sin(a)*R
        });
    }

    // 5. Bottom edge
    pts.push_back({ x+w-R,     y+h });
    pts.push_back({ x+R,       y+h });

    // 6. Bottom-left quarter-arc (90°→180°)
    for (int i = 1; i < arcSteps; ++i) {
        float a = 0.5f*PI + (PI/2)*(i/(float)arcSteps);
        pts.push_back({
            x +     R + std::cos(a)*R,
            y + h - R + std::sin(a)*R
        });
    }

    // 7. Left edge
    pts.push_back({ x,         y+h-R });
    pts.push_back({ x,         y+R });

    // 8. Top-left quarter-arc (180°→270°)
    for (int i = 1; i < arcSteps; ++i) {
        float a = PI      + (PI/2)*(i/(float)arcSteps);
        pts.push_back({
            x +     R + std::cos(a)*R,
            y +     R + std::sin(a)*R
        });
    }

    return pts;
}

static std::vector<float> BuildCumLengths(const std::vector<Vector2>& pts) {
    int m = (int)pts.size();
    std::vector<float> cum(m+1, 0.0f);
    for (int i = 0; i < m; ++i) {
        float dx = pts[i+1 == m ? 0 : i+1].x - pts[i].x;
        float dy = pts[i+1 == m ? 0 : i+1].y - pts[i].y;
        cum[i+1] = cum[i] + std::hypot(dx, dy);
    }
    return cum;
}

void DrawDashedRoundedRect(const Rectangle& rec,
                           float dashLen,
                           float gapLen,
                           float phase,
                           float radius,
                           int arcSteps,
                           float thickness,
                           Color color)
{
    static std::vector<Vector2> perimeter;
    static std::vector<float> cumLen;

    // Rebuild only if your rec/radius/arcSteps change:
    perimeter = BuildPerimeter(rec, radius, arcSteps);
    cumLen    = BuildCumLengths(perimeter);

    DrawDashedPolylineLoop(perimeter, cumLen,
                           dashLen, gapLen, phase,
                           thickness, color);
}


// Draws an animated dashed circle centered at 'center' with radius 'radius'.
// 'dashLength' and 'gapLength' define the pattern along the circumference.
// 'phase' shifts the pattern around the circle (advance by phase units).
// 'segments' is the resolution for approximating each dash arc.
// 'thickness' is the line width, 'color' is the circle color.
auto DrawDashedCircle(const Vector2 &center,
                      float radius,
                      float dashLength,
                      float gapLength,
                      float phase,
                      int segments,
                      float thickness,
                      Color color) -> void
{
    // circumference-based pattern
    const float pattern      = dashLength + gapLength;
    // clamp phase to [0, pattern)
    phase = std::fmod(phase, pattern);
    if (phase < 0) phase += pattern;

    // angles in radians
    const float dashAng  = dashLength / radius;
    const float gapAng   = gapLength  / radius;
    const float phaseAng = phase      / radius;

    // we'll do two sweeps: main, then wrapped
    auto drawSweep = [&](float startTheta, float endTheta)
    {
        float theta = startTheta;
        while (theta < endTheta)
        {
            float segStart = std::max(theta, startTheta);
            float segEnd   = std::min(theta + dashAng, endTheta);
            if (segEnd > segStart)
            {
                // approximate arc by subdividing proportional to full-circle segments
                int arcSegs = std::max(1,
                    (int)std::ceil((segEnd - segStart) / (2.0f * PI) * segments));
                for (int i = 0; i < arcSegs; ++i)
                {
                    float t1 = segStart + (segEnd - segStart) * i / (float)arcSegs;
                    float t2 = segStart + (segEnd - segStart) * (i + 1) / (float)arcSegs;
                    Vector2 p1 = { center.x + std::cos(t1) * radius,
                                   center.y + std::sin(t1) * radius };
                    Vector2 p2 = { center.x + std::cos(t2) * radius,
                                   center.y + std::sin(t2) * radius };
                    DrawLineEx(p1, p2, thickness, color);
                }
            }
            theta += dashAng + gapAng;
        }
    };

    // Primary arc from -phaseAng to (2π - phaseAng)
    drawSweep(-phaseAng, 2 * PI - phaseAng);

    // Wrapped arc: shift by +2π so any dash spilling over the top is drawn
    drawSweep(2 * PI - phaseAng, 2 * (2 * PI) - phaseAng);
}

// -- new shape calls
inline float rad2deg(float r) { return r * 180.0f / PI; }

// Pick a reasonable default tessellation for arcs/rings based on radius.
// Raylib wants an explicit segment count for DrawRing/DrawCircleSector.
inline int autoSegments(float radius) {
    // ~ 1 segment per 6 px of circumference, clamped.
    int seg = std::max(12, (int)std::round((2.0f * PI * radius) / 6.0f));
    return std::min(seg, 256);
}

// Convenience: default color when user doesn't supply one (mirrors LÖVE "state")
// We just pick WHITE; Raylib doesn't track a global draw color.
inline Color defaultColor() { return WHITE; }

// -----------------------------------------------------------------------------
// Arc types (LÖVE has "pie", "open", "closed")
// -----------------------------------------------------------------------------
enum class ArcType { Pie, Open, Closed };

inline ArcType ArcTypeFromString(const char* s) {
    if (!s) return ArcType::Open;
    if (std::strcmp(s, "pie") == 0)    return ArcType::Pie;
    if (std::strcmp(s, "closed") == 0) return ArcType::Closed;
    // LÖVE also uses "open"
    return ArcType::Open;
}

// -----------------------------------------------------------------------------
// Rectangle centered at (x,y). Optional rounded corners.
// rx, ry are pixel radii in LÖVE; Raylib only supports a single roundness.
// We map to roundness = min(rx,ry)/min(w,h). Different rx/ry are approximated.
// -----------------------------------------------------------------------------
inline void rectangle(float x, float y, float w, float h,
                      std::optional<float> rx = {},
                      std::optional<float> ry = {},
                      std::optional<Color> color = {},
                      std::optional<float> lineWidth = {}) {
    Rectangle rec{ x - w*0.5f, y - h*0.5f, w, h };

    const bool doStroke = lineWidth.has_value();
    const bool doFill   = color.has_value() && !doStroke;
    Color C = color.value_or(defaultColor());

    if (rx.has_value() || ry.has_value()) {
        // Raylib uses [0..1] roundness proportion of min(width,height).
        float px = rx.value_or(0.0f);
        float py = ry.value_or(px);
        float pxMin = std::max(0.0f, std::min(px, py));
        float roundness = (std::min(w, h) <= 0) ? 0.0f : std::clamp(pxMin / std::min(w, h), 0.0f, 1.0f);
        int segments = 12 + (int)std::round(8.0f * roundness);

        if (doStroke) {
            DrawRectangleRoundedLinesEx(rec, roundness, segments, std::max(1.0f, lineWidth.value()), C);
        } else {
            DrawRectangleRounded(rec, roundness, segments, C);
        }
        return;
    }

    if (doStroke) {
        DrawRectangleLinesEx(rec, std::max(1.0f, lineWidth.value()), C);
    } else if (doFill) {
        DrawRectangleRec(rec, C);
    } else {
        DrawRectangleLines((int)rec.x, (int)rec.y, (int)rec.width, (int)rec.height, C);
    }
}

// -----------------------------------------------------------------------------
// Isosceles triangle pointing right (angle 0), centered at (x,y), size w (height across) and h (length).
// -----------------------------------------------------------------------------
inline void triangle(float x, float y, float w, float h,
                     std::optional<Color> color = {},
                     std::optional<float> lineWidth = {}) {
    Vector2 p1{ x + h*0.5f, y };
    Vector2 p2{ x - h*0.5f, y - w*0.5f };
    Vector2 p3{ x - h*0.5f, y + w*0.5f };

    Color C = color.value_or(defaultColor());
    if (lineWidth.has_value()) {
        float t = std::max(1.0f, lineWidth.value());
        DrawLineEx(p1, p2, t, C);
        DrawLineEx(p2, p3, t, C);
        DrawLineEx(p3, p1, t, C);
    } else if (color.has_value()) {
        DrawTriangle(p1, p2, p3, C);
    } else {
        DrawTriangleLines(p1, p2, p3, C);
    }
}

// -----------------------------------------------------------------------------
// Equilateral triangle of width w, centered at (x,y), pointing right.
// -----------------------------------------------------------------------------
inline void triangle_equilateral(float x, float y, float w,
                                 std::optional<Color> color = {},
                                 std::optional<float> lineWidth = {}) {
    float h = std::sqrt(w*w - (w*0.5f)*(w*0.5f)); // = w*sqrt(3)/2
    triangle(x, y, w, h, color, lineWidth);
}

// -----------------------------------------------------------------------------
// Circle at (x,y) radius r
// - fill: DrawCircleV
// - 1px:  DrawCircleLines
// - thick stroke: DrawRing with inner/outer radii
// -----------------------------------------------------------------------------
inline void circle(float x, float y, float r,
                   std::optional<Color> color = {},
                   std::optional<float> lineWidth = {}) {
    Color C = color.value_or(defaultColor());
    Vector2 c{ x, y };

    if (lineWidth.has_value()) {
        float t = std::max(1.0f, lineWidth.value());
        float inner = std::max(0.0f, r - t*0.5f);
        float outer = r + t*0.5f;
        DrawRing(c, inner, outer, 0.0f, 360.0f, autoSegments(r), C);
    } else if (color.has_value()) {
        DrawCircleV(c, r, C);
    } else {
        DrawCircleLines((int)x, (int)y, r, C);
    }
}

// -----------------------------------------------------------------------------
// Arc: angles r1..r2 in RADIANS.
//  - Pie (filled wedge): DrawCircleSector
//  - Open (stroked arc only): DrawRing with small thickness or provided lineWidth
//  - Closed (stroked arc + chord): emulate with lines on ends + arc ring
// -----------------------------------------------------------------------------
inline void arc(ArcType type, float x, float y, float r, float r1, float r2,
                std::optional<Color> color = {},
                std::optional<float> lineWidth = {},
                int segments = 0) {
    Color C = color.value_or(defaultColor());
    Vector2 c{ x, y };
    float a1 = rad2deg(r1);
    float a2 = rad2deg(r2);
    if (a2 < a1) std::swap(a1, a2);

    int seg = (segments > 0) ? segments : autoSegments(r);

    if (!lineWidth.has_value() && color.has_value() && type == ArcType::Pie) {
        DrawCircleSector(c, r, a1, a2, seg, C);
        return;
    }

    // Stroke / open arc is best with a ring band
    float t = std::max(1.0f, lineWidth.value_or(1.0f));
    float inner = std::max(0.0f, r - t*0.5f);
    float outer = r + t*0.5f;
    DrawRing(c, inner, outer, a1, a2, seg, C);

    if (type == ArcType::Closed && !lineWidth.has_value()) {
        // If someone asked for "fill+closed" (rare in LÖVE), emulate a chord fill:
        // simple approach: draw two skinny triangles to the center; keep it simple.
        // (Keeping this minimal per your "use built-ins" request.)
        DrawLineEx(c, Vector2{ x + r*std::cos(r1), y + r*std::sin(r1) }, 1.0f, C);
        DrawLineEx(c, Vector2{ x + r*std::cos(r2), y + r*std::sin(r2) }, 1.0f, C);
    }
}

// Convenience overload matching your LÖVE signature where arctype is a string.
inline void arc(const char* arctype, float x, float y, float r, float r1, float r2,
                std::optional<Color> color = {},
                std::optional<float> lineWidth = {},
                int segments = 0) {
    arc(ArcTypeFromString(arctype), x, y, r, r1, r2, color, lineWidth, segments);
}

// -----------------------------------------------------------------------------
// Polygon: vertices in order. For fill, assumes convex (or star-shaped) for DrawTriangleFan.
// Stroke uses DrawLineEx per edge; closed polygon.
// -----------------------------------------------------------------------------
inline void polygon(const std::vector<Vector2>& vertices,
                    std::optional<Color> color = {},
                    std::optional<float> lineWidth = {}) {
    if (vertices.size() < 2) return;
    Color C = color.value_or(defaultColor());

    if (lineWidth.has_value()) {
        float t = std::max(1.0f, lineWidth.value());
        for (size_t i = 0; i < vertices.size(); ++i) {
            const Vector2& a = vertices[i];
            const Vector2& b = vertices[(i + 1) % vertices.size()];
            DrawLineEx(a, b, t, C);
        }
    } else if (color.has_value()) {
        // Simple convex fill path: triangle fan from v0
        rlBegin(RL_TRIANGLES);
        rlColor4ub(C.r, C.g, C.b, C.a);
        const Vector2& v0 = vertices[0];
        for (size_t i = 1; i + 1 < vertices.size(); ++i) {
            const Vector2& v1 = vertices[i];
            const Vector2& v2 = vertices[i + 1];
            rlVertex2f(v0.x, v0.y);
            rlVertex2f(v1.x, v1.y);
            rlVertex2f(v2.x, v2.y);
        }
        rlEnd();
    } else {
        for (size_t i = 0; i < vertices.size(); ++i) {
            const Vector2& a = vertices[i];
            const Vector2& b = vertices[(i + 1) % vertices.size()];
            DrawLineV(a, b, C);
        }
    }
}

// -----------------------------------------------------------------------------
// Line: (x1,y1)-(x2,y2)
// -----------------------------------------------------------------------------
inline void line(float x1, float y1, float x2, float y2,
                 std::optional<Color> color = {},
                 std::optional<float> lineWidth = {}) {
    Color C = color.value_or(defaultColor());
    if (lineWidth.has_value()) {
        DrawLineEx(Vector2{ x1,y1 }, Vector2{ x2,y2 }, std::max(1.0f, lineWidth.value()), C);
    } else {
        DrawLine((int)x1, (int)y1, (int)x2, (int)y2, C);
    }
}

// -----------------------------------------------------------------------------
// Polyline: draw connected segments (open path).
// -----------------------------------------------------------------------------
inline void polyline(const std::vector<Vector2>& points,
                     std::optional<Color> color = {},
                     std::optional<float> lineWidth = {}) {
    if (points.size() < 2) return;
    Color C = color.value_or(defaultColor());
    float t = std::max(1.0f, lineWidth.value_or(1.0f));
    for (size_t i = 0; i + 1 < points.size(); ++i) {
        DrawLineEx(points[i], points[i + 1], t, C);
    }
}

// -----------------------------------------------------------------------------
// Rounded line caps: DrawLineEx + two endpoint circles for perfect round caps.
// -----------------------------------------------------------------------------
inline void rounded_line(float x1, float y1, float x2, float y2,
                         std::optional<Color> color = {},
                         std::optional<float> lineWidth = {}) {
    Color C = color.value_or(defaultColor());
    float t = std::max(1.0f, lineWidth.value_or(1.0f));
    Vector2 a{ x1,y1 }, b{ x2,y2 };
    DrawLineEx(a, b, t, C);
    DrawCircleV(a, t*0.5f, C);
    DrawCircleV(b, t*0.5f, C);
}

// -----------------------------------------------------------------------------
// Ellipse centered at (x,y) with radii rx, ry.
// - fill: DrawEllipse
// - 1px stroke: DrawEllipseLines
// - thick stroke: emulate with scaled ring (rlScale), keeping it simple.
// -----------------------------------------------------------------------------
inline void ellipse(float x, float y, float rx, float ry,
                    std::optional<Color> color = {},
                    std::optional<float> lineWidth = {}) {
    Color C = color.value_or(defaultColor());
    if (lineWidth.has_value()) {
        float t = std::max(1.0f, lineWidth.value());
        // Draw a unit circle ring at origin, scale to rx/ry, then translate.
        // This keeps to built-ins (DrawRing) and avoids manual tessellation.
        rlPushMatrix();
        rlTranslatef(x, y, 0.0f);
        rlScalef(1.0f, ry / rx, 1.0f); // scale Y so a circle of radius rx becomes ellipse rx,ry
        float inner = std::max(0.0f, rx - t*0.5f);
        float outer = rx + t*0.5f;
        DrawRing(Vector2{0,0}, inner, outer, 0.0f, 360.0f, autoSegments(rx), C);
        rlPopMatrix();
    } else if (color.has_value()) {
        DrawEllipse((int)x, (int)y, (int)rx, (int)ry, C);
    } else {
        DrawEllipseLines((int)x, (int)y, (int)rx, (int)ry, C);
    }
}


// -- immediate sprite render
auto DrawSpriteTopLeft(const std::string& spriteName,
                       float x, float y,
                       std::optional<float> dstW = std::nullopt,
                       std::optional<float> dstH = std::nullopt,
                       Color tint = WHITE) -> void
{
    // Resolve atlas frame + texture
    const auto spriteId = uuid::add(spriteName);
    const auto& sfd = init::getSpriteFrame(spriteId); // expects .frame and .atlasUUID

    auto it = globals::textureAtlasMap.find(sfd.atlasUUID);
    if (it == globals::textureAtlasMap.end()) {
        // TraceLog(LOG_WARNING, "Atlas texture not found for sprite '%s'", spriteName.c_str());
        return;
    }

    Texture2D* tex = &it->second;
    const Rectangle src = sfd.frame;

    // Destination size (native if not provided). Keep aspect if only one is set.
    float w = dstW.value_or(src.width);
    float h = dstH.value_or(src.height);
    if (dstW && !dstH) {
        h = w * (src.height / src.width);
    } else if (dstH && !dstW) {
        w = h * (src.width / src.height);
    }

    // Top-left anchored destination rect
    const Rectangle dst = { x, y, w, h };
    const Vector2   origin = { 0.0f, 0.0f };

    DrawTexturePro(*tex, src, dst, origin, 0.0f, tint);
}

// Draw the sprite named `spriteName` centered at (x,y).
// - If both dstW and dstH are unset, draws at native (frame) size.
// - If only one is set, preserves aspect ratio to compute the other.
// - `tint` tints the sprite (WHITE = unchanged).
auto DrawSpriteCentered(const std::string& spriteName,
                        float x, float y,
                        std::optional<float> dstW = std::nullopt,
                        std::optional<float> dstH = std::nullopt,
                        Color tint = WHITE) -> void
{
    // Resolve atlas frame + texture
    const auto spriteId = uuid::add(spriteName);
    const auto &sfd = init::getSpriteFrame(spriteId); // expect: has .frame (Rectangle) and .atlasUUID

    auto it = globals::textureAtlasMap.find(sfd.atlasUUID);
    if (it == globals::textureAtlasMap.end()) {
        // TODO: replace with your logging/error path
        // TraceLog(LOG_WARNING, "Atlas texture not found for sprite '%s'", spriteName.c_str());
        return;
    }

    Texture2D *tex = &it->second;
    const Rectangle src = sfd.frame; // sub-rect in the atlas

    // Determine destination size
    float w = dstW.value_or(src.width);
    float h = dstH.value_or(src.height);
    if (dstW && !dstH) {                 // width forced, keep aspect
        h = w * (src.height / src.width);
    } else if (dstH && !dstW) {          // height forced, keep aspect
        w = h * (src.width / src.height);
    }

    // Centered destination rect
    const Rectangle dst = { x - 0.5f * w, y - 0.5f * h, w, h };

    // No rotation; origin is top-left of dst
    const Vector2 origin = { 0.0f, 0.0f };
    DrawTexturePro(*tex, src, dst, origin, 0.0f, tint);
}



#include "rlgl.h"
#include "external/glad.h"

// Stencil masks

void clearStencilBuffer()
{
    rlDrawRenderBatchActive();
    glStencilMask(0xFF);      // make sure all bits can be cleared
    glClearStencil(0);        // the value they’ll be cleared to
    glClear(GL_STENCIL_BUFFER_BIT);
}

void beginStencil()
{
    rlDrawRenderBatchActive();
    glEnable(GL_STENCIL_TEST);

    // Clear all existing stencil bits to zero, and allow writing to all bits:
    glClear(GL_STENCIL_BUFFER_BIT);
    glStencilMask(0xFF);
}

void beginStencilMask()
{
	glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
	glStencilFunc(GL_ALWAYS, 1, 0xFF);
	glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
}

void endStencilMask()
{
    rlDrawRenderBatchActive();
    // Now only draw where stencil == 1, and never change the stencil buffer:
    glStencilFunc(GL_EQUAL, 1, 0xFF);
    glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);

    // Stop writing to stencil bits
    glStencilMask(0x00);

    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
}

void endStencil()
{
	rlDrawRenderBatchActive();
	glDisable(GL_STENCIL_TEST);
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
        
        //--------------------
        // testing
        
        
        
        // 1) Compute your sample point and the BB you’re querying:
        cpVect pt = cpv((0 + 0.5f)*_tileCache->_tileSize + _tileCache->_tileOffset.x,
                        (0 + 0.5f)*_tileCache->_tileSize + _tileCache->_tileOffset.y);
        cpBB   queryBB = cpBBNewForCircle(pt, 0.0f);
        
        // 2) Log what you’re about to ask:
        // spdlog::info("Querying spatial index at pt = ({:.2f}, {:.2f}), BB = l={:.2f},b={:.2f},r={:.2f},t={:.2f}",
        //      pt.x, pt.y,
        //      queryBB.l, queryBB.b, queryBB.r, queryBB.t);
             
        // 3) Wrap your callback in a named function so you can add logs:
        auto debugQuery = +[](void *obj, void *queryObj, cpCollisionID, void *userData) -> unsigned {
            auto *tile  = static_cast<CachedTile*>(obj);
            auto *point = static_cast<cpVect*>(queryObj);

            // log each candidate tile the index returns:
            // spdlog::info("  → candidate tile BB l={:.2f},b={:.2f},r={:.2f},t={:.2f}; checking point ({:.2f},{:.2f})",
            //             tile->bb.l, tile->bb.b, tile->bb.r, tile->bb.t,
            //             point->x, point->y);

            if(cpBBContainsVect(tile->bb, *point)) {
                *static_cast<CachedTile**>(userData) = tile;
                spdlog::info("    → point INSIDE this tile!");
                return 1;   // stop on first hit
            }
            return 0;
        };

        // 4) Fire the query and capture the return count:
        CachedTile* out = nullptr;
        cpSpatialIndexQuery(
            _tileCache->_tileIndex,
            &pt,
            queryBB,
            debugQuery,
            &out
        );
        
        // world coordinate of my query is (0, 0)
        cpVect queryPointWorldRaylibGridTopLeft = cpv(0, 0);
        
        // actual coordinate of the query point in the tile cache -> this actually centers the point in the tile, which we don't want.
        Vector2 queryPointWorldRaylibPixels = {
            (float)((queryPointWorldRaylibGridTopLeft.x + 0.5f) * _tileCache->_tileSize) + (float)_tileCache->_tileOffset.x,
            (float)((queryPointWorldRaylibGridTopLeft.y + 0.5f) * _tileCache->_tileSize) + (float)_tileCache->_tileOffset.y
        };
        
        cpVect rectWidthHeight = cpv(_tileCache->_tileSize, _tileCache->_tileSize);
        
        // convert to chimunk coords
        cpVect queryPointPhysics = physics::raylibToChipmunkCoords(queryPointWorldRaylibPixels);
        
        // Pick the world coords of the tile’s top-left and bottom-right:
        float l = queryPointWorldRaylibGridTopLeft.x * _tileCache->_tileSize, 
              t = queryPointWorldRaylibGridTopLeft.y * _tileCache->_tileSize,
              r = l + rectWidthHeight.x, 
              b = t + rectWidthHeight.y;

        // top-left in world is (l, t)
        auto worldCamera = camera_manager::Get("world_camera");
        Vector2 screenTL = GetWorldToScreen2D({(float) l, (float)t }, worldCamera->cam);
        // bottom-right in world is (r, b)
        Vector2 screenBR = GetWorldToScreen2D({ (float)r, (float)b }, worldCamera->cam);

        layer::QueueCommand<layer::CmdDrawRectangle>(
        sprites, [screenTL, screenBR](auto* cmd) {
            cmd->x      = screenTL.x + 0.5f * (screenBR.x - screenTL.x); // center the rectangle
            cmd->y      = screenTL.y + 0.5f * (screenBR.y - screenTL.y); // center the rectangle
            cmd->width  = screenBR.x - screenTL.x; // width is positive
            cmd->height = screenBR.y - screenTL.y; // height is positive
            cmd->color  = RED;
        }, 1000
        );
        
        // Draw the query point (yellow dot)
        Vector2 pScr = GetWorldToScreen2D({64,64}, worldCamera->cam);
        // DrawCircleV(pScr, 4.0f, YELLOW);
        layer::QueueCommand<layer::CmdDrawCircleFilled>(
            sprites, [pScr](auto* cmd) {
                cmd->x = pScr.x;
                cmd->y = pScr.y;
                cmd->radius = 4.0f;
                cmd->color = YELLOW;
            },
            1000 // zIndex for debug drawing
        );
        
        // draw density texture
        // layer::QueueCommand<layer::CmdDrawImage>(
        //     sprites, [](auto* cmd) {
        //         // cmd->image = blockSamplerTexture;
        //         cmd->image = pointCloudSamplerTexture;
        //         cmd->x = 0;
        //         cmd->y = 0;
        //         cmd->scaleX = 1.0f;
        //         cmd->scaleY = 1.0f;
        //         cmd->color = WHITE;
        //     },
        //     1000, // zIndex for debug drawing
        //     layer::DrawCommandSpace::World // draw in world space
        // );
        
        // end testing ---------------------


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
            auto textView = globals::registry.view<TextSystem::Text, entity_gamestate_management::StateTag>(entt::exclude<ui::ObjectAttachedToUITag>);
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
            auto spriteView = globals::registry.view<AnimationQueueComponent, entity_gamestate_management::StateTag>(entt::exclude<ui::ObjectAttachedToUITag>);
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
                    // SPDLOG_DEBUG("Drawing animated sprite {} in world space at zIndex {}", (int)e, zIndex);
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
                layer::DrawLayerCommandsToSpecificCanvasApplyAllShaders(background, "main", &worldCamera->cam);  // render the background layer commands to its main canvas
            }
            
            
            
            {
                // ZoneScopedN("sprites layer commands");
                layer::DrawLayerCommandsToSpecificCanvasApplyAllShaders(sprites, "main", &worldCamera->cam);     // render the sprite layer commands to its main canvas
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
            
            
            
            
            
            layer::Push(&worldCamera->cam);

            
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
#ifndef __EMSCRIPTEN__
                // ZoneScopedN("Debug UI");
                rlImGuiBegin(); // Required: starts ImGui frame

                shaders::ShowShaderEditorUI(globals::globalShaderUniforms);
                ShowDebugUI();

                rlImGuiEnd(); // Required: renders ImGui on top of Raylib
#endif
            }
            

            // Display UPS and FPS
            // DrawText(fmt::format("UPS: {} FPS: {}", main_loop::mainLoop.renderedUPS, GetFPS()).c_str(), 10, 10, 20, RED);
            
            // -- draw physics world
            
            camera_manager::Begin(worldCamera->cam); // begin camera mode for the physics world
            
            // --testing stencil 
            clearStencilBuffer(); // clear the stencil buffer
            beginStencil();
            beginStencilMask();

            
            endStencilMask();
            
            
            physics::ChipmunkDemoDefaultDrawImpl(physicsWorld->space);
            
            endStencil();
            
            

            camera_manager::End(); // end camera mode for the physics world
            
            // rect in the center   
            DrawRectangleLines(
                GetScreenWidth() / 2 - 100, 
                GetScreenHeight() / 2 - 100, 
                200, 200, 
                RED
            );
            
            fade_system::draw();
            
            static float phase = 0;
            phase += dt * 10.0f; // advance phase for dashes
            // -- testing --
            // DrawDashedCircle({ 100, 100 }, 50, 10, 5, phase, 32, 2, GREEN);
            // DrawDashedLine({ 200, 200 }, { 300, 300 }, 10, 5, phase, 2, GREEN);
            // DrawDashedRoundedRect(
            //     { 400, 400, 200, 100 }, // rectangle
            //     10,                   // dash length
            //     5,                    // gap length
            //     phase,                // phase
            //     20,                   // radius
            //     16,                   // arc steps
            //     2,                    // thickness
            //     BLUE                 // color
            // );
            ellipse(
                600, 600, 100, 50, // center x, y, radius x, radius y
                std::nullopt,      // no color (default to WHITE)
                std::nullopt       // no line width (default to 1px)
            );
            rounded_line(
                700, 700, 800, 800, // start x, y, end x, y
                std::nullopt,       // no color (default to WHITE)
                30        // no line width (default to 1px)
            );
            polyline(
                { { 900, 900 }, { 950, 850 }, { 1000, 700 }, { 950, 300 } }, // points
                YELLOW, // no color (default to WHITE)
                20  // no line width (default to 1px)
            );
            polygon(
                { { 1100, 850 }, { 1150, 400 }, { 1200, 500 }, { 1150, 800 } }, // vertices
                GREEN, // no color (default to WHITE)
                5  // no line width (default to 1px)
            );
            arc(
                ArcType::Pie, // type
                600, 200, 100, // center x, y, radius
                0, PI / 2, // start angle, end angle
                std::nullopt, // no color (default to WHITE)
                std::nullopt, // no line width (default to 1px)
                32 // segments
            );
            triangle_equilateral(
                1400, 700, 100, // center x, y, width
                std::nullopt, // no color (default to WHITE)
                std::nullopt  // no line width (default to 1px)
            );
            rectangle(
                1500, 300, 200, 100, // center x, y, width, height
                10, 
                10, 
                std::nullopt, // no color (default to WHITE)
                std::nullopt  // no line width (default to 1px)
            );
            
            DrawSpriteCentered("star_09.png", 500, 500, 
                               std::nullopt, std::nullopt, GREEN); // draw centered sprite
            DrawCircle(500, 500, 10, YELLOW); // draw circle
            
            DrawSpriteTopLeft("keyboard_w_outline.png", 500, 500, 
                              std::nullopt, std::nullopt, WHITE); // draw top-left sprite
                              
            // ldtk_loader::DrawAllLayers("Everything");
            ldtk_loader::DrawAllLayers("Background_image");
            // ldtk_loader::DrawAllLayers("Tiles_and_intgrid");
            // ldtk_loader::DrawAllLayers("Autolayer");

            {
                // ZoneScopedN("EndDrawing call");
                EndDrawing();
            }

            layer::Pop();


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