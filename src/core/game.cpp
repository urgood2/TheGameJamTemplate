
#include <memory>

#include "../util/utilities.hpp"

#include "graphics.hpp"
#include "globals.hpp"

#include "../components/components.hpp"
#include "../components/graphics.hpp"

#include "game.hpp" // game.hpp must be included after components.hpp
#include "magic_enum/magic_enum.hpp"
#include "gui.hpp"
#include "raymath.h"

#include "../third_party/rlImGui/extras/IconsFontAwesome6.h"
#include "../third_party/rlImGui/imgui_internal.h"

#include "../systems/movable/my_own_movable_impl.hpp"
#include "../systems/shaders/shader_system.hpp"
#include "../systems/event/event_system.hpp"
#include "../systems/sound/sound_system.hpp"
#include "../systems/text/textVer2.hpp"
#include "../systems/ui/common_definitions.hpp"
#include "../systems/ui/inventory_ui.hpp"
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

#include "systems/layer/layer.hpp"
#include "systems/shaders/shader_system.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/input/input_functions.hpp"
#include "systems/ui/ui.hpp"
#include "systems/ui/util.hpp"
#include "systems/timer/timer.hpp"
#include "systems/particles/particle.hpp"
#include "systems/random/random.hpp"
#include "systems/second_order_dynamics/second_order_dynamics.hpp"

#include "entt/entt.hpp"

#include "third_party/rlImGui/rlImGui.h"

#include "raymath.h"

// make layers to draw to
std::shared_ptr<layer::Layer> background;  // background
std::shared_ptr<layer::Layer> sprites;     // sprites
std::shared_ptr<layer::Layer> ui_layer;    // ui
std::shared_ptr<layer::Layer> finalOutput; // final output (for post processing)

// AsteroidManager *asteroidManager = nullptr;

// example entity
entt::entity player{entt::null};

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

float transitionShaderPositionVar = 0.f;

namespace game
{
    
    std::string randomStringText{};
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
        "bump",
        "wiggle",
        "pop",
        "slide",
        "pulse",
        "shake"
    };

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

    ui::UIElementTemplateNode getRandomRectDef()
    {
        return ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::RECT_SHAPE)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(GREEN)
                    .addHover(true)
                    // .addOnePress(true)
                    .addButtonCallback([]()
                                       { SPDLOG_DEBUG("Button callback triggered"); })
                    .addWidth(Random::get<float>(20, 100))
                    .addHeight(Random::get<float>(20, 100))
                    .addMinWidth(200.f)
                    .addOutlineThickness(5.0f)
                    // .addShadowColor(Fade(BLACK, 0.4f))
                    .addShadow(true)
                    // .addEmboss(4.f)
                    // .addOutlineThickness(2.0f)
                    .addOutlineColor(BLUE)
                    // .addShadow(true)
                    .build())
            .build();

        // TODO: templates for timer
        // TODO: how to chain timer calls optionally in a queue
    }

    // returns a UIElementTemplateNode for UITypeEnum::TEXT (no container)
    ui::UIElementTemplateNode getNewTextEntry(std::string text, std::optional<entt::entity> refEntity = std::nullopt, std::optional<std::string> refComponent = std::nullopt, std::optional<std::string> refValue = std::nullopt) {
        auto configBuilder = ui::UIConfig::Builder::create()
            .addColor(WHITE)
            .addText(text)
            .addShadow(true)
            .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT | transform::InheritedProperties::Alignment::VERTICAL_CENTER);

        if (refEntity && refComponent && refValue) {
            configBuilder.addRefEntity(*refEntity)
                .addRefComponent(*refComponent)
                .addRefValue(*refValue);
        }

        auto node = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::TEXT)
            .addConfig(configBuilder.build());

        return node.build();        
    }

    //TODO: set up dynamic updating for dynamic text through refEntity, refComponent, refValue -> make updates cause texts to jiggle, or something like that, ideally have a configurable trigger
    ui::UIElementTemplateNode getNewDynamicTextEntry(std::string text, float fontSize, std::optional<float> wrapWidth, std::optional<std::string> textEffect = std::nullopt, std::optional<entt::entity> refEntity = std::nullopt, std::optional<std::string> refComponent = std::nullopt, std::optional<std::string> refValue = std::nullopt) {

        TextSystem::Text textData = {
            // .rawText = fmt::format("[안녕하세요](color=red;shake=2,2). Here's a UID: [{}](color=red;pulse=0.9,1.1)", testUID),
            // .rawText = fmt::format("[안녕하세요](color=red;rotate=2.0,5;float). Here's a UID: [{}](color=red;pulse=0.9,1.1,3.0,4.0)", testUID),
            
            .rawText = text,
            .fontData = globals::fontData,
            .fontSize = fontSize,
            .wrapEnabled = wrapWidth ? true : false,
            .wrapWidth = wrapWidth.value_or(0.0f),
            .alignment = TextSystem::Text::Alignment::LEFT,
            .wrapMode = TextSystem::Text::WrapMode::WORD
        };

        auto textEntity = TextSystem::Functions::createTextEntity(textData, 0, 0);

        if (textEffect) {
            TextSystem::Functions::applyGlobalEffects(textEntity, textEffect.value_or(""));
        }

        auto configBuilder = ui::UIConfig::Builder::create()
            .addObject(textEntity)
            .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT | transform::InheritedProperties::Alignment::VERTICAL_CENTER);

        if (refEntity && refComponent && refValue) {
            configBuilder.addRefEntity(*refEntity)
                .addRefComponent(*refComponent)
                .addRefValue(*refValue);
        }

        timer::TimerSystem::timer_every(3.f, [textEntity](std::optional<float> f) {
            TextSystem::Functions::debugPrintText(textEntity);
        });

        auto node = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::OBJECT)
            .addConfig(configBuilder.build());

        return node.build();        
    }

    


    // perform game-specific initialization here. This makes it easier to find all the initialization code
    // specific to a game project
    auto init() -> void
    {
        testInventory = ui::createNewObjectArea(
            globals::registry,
            globals::gameWorldContainerEntity,
            2,
            2,
            50.f,
            50.f);
        auto &testInventoryTransform = globals::registry.get<transform::Transform>(testInventory);
        testInventoryTransform.setActualX(300);
        testInventoryTransform.setActualY(300);

        // load font
        // globals::fontData.font = LoadFontEx(util::getAssetPathUUIDVersion("fonts/en/slkscr.ttf").c_str(), 40, 0, 250);
        globals::fontData.font = LoadFontEx(util::getAssetPathUUIDVersion("fonts/en/Ac437_IBM_BIOS.ttf").c_str(), 40, 0, 250);
        globals::fontData.fontScale = 1.0f;

        //REVIEW: text entries have to be duplicated before being assigned to ui templates.

        text = {
            // .rawText = fmt::format("[안녕하세요](color=red;shake=2,2). Here's a UID: [{}](color=red;pulse=0.9,1.1)", testUID),
            // .rawText = fmt::format("[안녕하세요](color=red;rotate=2.0,5;float). Here's a UID: [{}](color=red;pulse=0.9,1.1,3.0,4.0)", testUID),
            
            .rawText = fmt::format("[HEY HEY!](rainbow;bump)"),
            .fontData = globals::fontData,
            .fontSize = 50.0f,
            .wrapEnabled = false,
            // .wrapWidth = 1200.0f,
            .alignment = TextSystem::Text::Alignment::LEFT,
            .wrapMode = TextSystem::Text::WrapMode::WORD};
        // text.get_value_callback = []() {
        //     return randomStringText; // updates text entity based on randomStringText
        // };

        // make this text update regularly, with a new effect
        // timer::TimerSystem::timer_every(5.f, [](std::optional<float> f) {
        //     randomStringText = random_utils::random_element(randomStringTextList); // change the variable referenced by the text entity

        //     // clear all effects
        //     TextSystem::Functions::clearAllEffects(textEntity);

        //     // set new random effect to update on text change
        //     auto &text = globals::registry.get<TextSystem::Text>(textEntity);
        //     text.effectStringsToApplyGloballyOnTextChange.clear();
        //     text.effectStringsToApplyGloballyOnTextChange.push_back(random_utils::random_element(randomEffects));
        // });

        text.onFinishedEffect = []()
        {
            // spdlog::debug("Text effect finished.");

            // // There is a brief flash of white when text changes. why?

            // auto &text = globals::registry.get<TextSystem::Text>(textEntity);
            // TextSystem::Functions::clearAllEffects(textEntity);
            // text.rawText = fmt::format("[some new text](rainbow;bump)");
            // TextSystem::Functions::parseText(textEntity);
            // TextSystem::Functions::applyGlobalEffects(textEntity, "pop=0.4,0.1,in;"); // ;
            // TextSystem::Functions::updateText(textEntity, 0.05f);                     // call update once to apply effects, prevent flashing
        };

        // FIXME: there are two text entities which overlap
        // FIXME: characters are not disposed of properly when text changes
        // FIXME: text offset not working properly when text changes

        // init custom text system
        // TextSystem::Functions::initEffects(text);
        // TextSystem::Functions::parseText(text);

        textEntity = TextSystem::Functions::createTextEntity(text, 0, 0);

        auto textEntity2 = TextSystem::Functions::createTextEntity(text, 300, 300); // testing

        // TextSystem::Functions::clearAllEffects(text);
        // TextSystem::Functions::applyGlobalEffects(textEntity, "pop=0.4,0.1,out;spin=4,0.1;"); // ;

        // set camera to fill the screen
        globals::camera = {0};
        globals::camera.zoom = 1;
        globals::camera.target = {GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f};
        globals::camera.rotation = 0;
        globals::camera.offset = {GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f};

        // SetTextureWrap(globals::spriteAtlas, TEXTURE_WRAP_CLAMP);
        // rlTextureParameters(globals::spriteAtlas.id, RL_TEXTURE_WRAP_S, TEXTURE_WRAP_CLAMP);
        // rlTextureParameters(globals::spriteAtlas.id, RL_TEXTURE_WRAP_T, TEXTURE_WRAP_CLAMP);

        sound_system::SetCategoryVolume("ui", 0.8f);

        // ImGui::GetIO().FontGlobalScale = 1.5f; // Adjust the scaling factor as needed

        // reflection for user registered componenets
        ui::util::RegisterMeta();

        // create layer the size of the screen, with a main canvas the same size
        background = layer::CreateLayerWithSize(GetScreenWidth(), GetScreenHeight());
        sprites = layer::CreateLayerWithSize(GetScreenWidth(), GetScreenHeight());
        ui_layer = layer::CreateLayerWithSize(GetScreenWidth(), GetScreenHeight());
        finalOutput = layer::CreateLayerWithSize(GetScreenWidth(), GetScreenHeight());

        // set camera to fill the screen
        globals::camera2D = {0};
        globals::camera2D.zoom = 1;
        globals::camera2D.target = {GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f};
        globals::camera2D.rotation = 0;
        globals::camera2D.offset = {GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f};

        // create entt::entity, give animation, which will update automatically thanks to animation system, which is updated in the main loop
        player = animation_system::createAnimatedObjectWithTransform("idle_animation", 400, 400);
        auto &playerTransform = globals::registry.get<transform::Transform>(player);
        auto &playerNode = globals::registry.get<transform::GameObject>(player);
        playerNode.debug.debugText = "Player";
        playerNode.state.dragEnabled = true;
        playerNode.state.hoverEnabled = true;
        playerNode.state.collisionEnabled = true;
        playerNode.state.clickEnabled = true;

        // massive container the size of the screen
        transformEntity = transform::CreateOrEmplace(&globals::registry, globals::gameWorldContainerEntity, 0, 0, 200, 200);
        auto &node = globals::registry.get<transform::GameObject>(transformEntity);
        node.debug.debugText = "Parent";
        node.state.dragEnabled = true;
        // TODO: clicking + dragging doesn't work when hover is not enabled.
        node.state.hoverEnabled = true;
        node.state.collisionEnabled = true;
        node.state.clickEnabled = true;
        auto &transform = globals::registry.get<transform::Transform>(transformEntity);
        transform.setActualX(100);
        transform.setActualY(100);
        // transform.setActualR(45.f);
        transform::debugMode = true; // enable debug drawing of transforms

        // Testing ui
        auto &uiConfig = globals::registry.emplace<ui::UIConfig>(transformEntity);
        uiConfig.color = RED;
        uiConfig.outlineThickness = 4.0f;
        uiConfig.outlineColor = YELLOW;
        uiConfig.shadowColor = Fade(BLACK, 0.4f);
        uiConfig.shadow = true;
        uiConfig.emboss = 5.f;

        childEntity = transform::CreateOrEmplace(&globals::registry, globals::gameWorldContainerEntity, 0, 0, 50, 50);
        auto &childNode = globals::registry.get<transform::GameObject>(childEntity);
        childNode.debug.debugText = "Fixture 1";
        auto &childTransform = globals::registry.get<transform::Transform>(childEntity);
        childTransform.setActualX(200);
        childTransform.setActualY(200);
        // TODO: how to make something act like it was actually tacked on to the parent? probably add a flag to allow special case handling for this (like a badge attached to a card, moves uniformly with the card)
        transform::AssignRole(&globals::registry, childEntity, transform::InheritedProperties::Type::PermanentAttachment, transformEntity, transform::InheritedProperties::Sync::Strong, transform::InheritedProperties::Sync::Strong, transform::InheritedProperties::Sync::Strong, transform::InheritedProperties::Sync::Strong, Vector2{});
        auto &childRole = globals::registry.get<transform::InheritedProperties>(childEntity);
        childRole.flags->alignment = transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT | transform::InheritedProperties::Alignment::VERTICAL_CENTER | transform::InheritedProperties::Alignment::ALIGN_TO_INNER_EDGES;

        childEntity2 = transform::CreateOrEmplace(&globals::registry, globals::gameWorldContainerEntity, 0, 0, 40, 20);
        auto &childNode2 = globals::registry.get<transform::GameObject>(childEntity2);
        childNode2.debug.debugText = "Fixture 2";
        auto &childTransform2 = globals::registry.get<transform::Transform>(childEntity2);
        transform::AssignRole(&globals::registry, childEntity2, transform::InheritedProperties::Type::PermanentAttachment, transformEntity, transform::InheritedProperties::Sync::Strong, transform::InheritedProperties::Sync::Strong, transform::InheritedProperties::Sync::Strong, transform::InheritedProperties::Sync::Strong, Vector2{});
        auto &childRole2 = globals::registry.get<transform::InheritedProperties>(childEntity2);
        childRole2.flags->alignment = transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT | transform::InheritedProperties::Alignment::VERTICAL_CENTER;

        childEntity3 = transform::CreateOrEmplace(&globals::registry, globals::gameWorldContainerEntity, 0, 0, 200, 40);
        auto &childNode3 = globals::registry.get<transform::GameObject>(childEntity3);
        childNode3.debug.debugText = "Not fixture";
        auto &childTransform3 = globals::registry.get<transform::Transform>(childEntity3);
        transform::AssignRole(&globals::registry, childEntity3, transform::InheritedProperties::Type::RoleInheritor, transformEntity, transform::InheritedProperties::Sync::Strong, std::nullopt, transform::InheritedProperties::Sync::Strong, std::nullopt, Vector2{50.f, 50.f});
        auto &childRole3 = globals::registry.get<transform::InheritedProperties>(childEntity3);
        childRole3.flags->alignment = transform::InheritedProperties::Alignment::HORIZONTAL_LEFT | transform::InheritedProperties::Alignment::VERTICAL_BOTTOM;

        // TODO: how to queue events with this timer?
        timer::TimerSystem::timer_every(5.0f, [](std::optional<float> f)
                                        {
        // SPDLOG_DEBUG("Injecting dynamic motion");
        transform::InjectDynamicMotion(&globals::registry, transformEntity, .5f); });

        timer::TimerSystem::timer_every(4.0f, [](std::optional<float> f)
                                        { 
                                            SPDLOG_DEBUG("{}", ui::box::DebugPrint(globals::registry, uiBox, 0)); 
                                            TextSystem::Functions::debugPrintText(textEntity);
                                        });

        timer::TimerSystem::timer_every(4.0f, [](std::optional<float> f)
                                        {
                                            particle::Particle particle{
                                                .velocity = Vector2{Random::get<float>(-200, 200), Random::get<float>(-200, 200)},
                                                .rotation = Random::get<float>(0, 360),
                                                .rotationSpeed = Random::get<float>(-180, 180),
                                                .scale = Random::get<float>(1, 10),
                                                .lifespan = Random::get<float>(1, 3),
                                                .color = random_utils::random_element<Color>({RED, GREEN, BLUE, YELLOW, ORANGE, PURPLE, PINK, BROWN, WHITE, BLACK})};

                                            // TODO: way to programatically modify frame times for animation

                                            particle::CreateParticle(globals::registry,
                                                                     GetMousePosition(),
                                                                     Vector2{10, 10},
                                                                     particle,
                                                                     particle::ParticleAnimationConfig{.loop = true, .animationName = "sword_anim"});
                                        });

        auto &testConfig = globals::registry.emplace<ui::Tooltip>(transformEntity);
        testConfig.title = "Test Tooltip";

        reflection::registerMetaForComponent<ui::Tooltip>([](auto meta)
                                                          { meta.type("Tooltip"_hs) // Ensure type name matches the lookup string
                                                                .template data<&ui::Tooltip::title>("title"_hs)
                                                                .template data<&ui::Tooltip::text>("text"_hs); });

        auto type = entt::resolve("Tooltip"_hs);
        auto test = reflection::retrieveComponent(&globals::registry, transformEntity, "Tooltip");

        ui::UIElementTemplateNode uiTextEntry = ui::UIElementTemplateNode::Builder::create()
                                                    .addType(ui::UITypeEnum::TEXT)
                                                    .addConfig(
                                                        ui::UIConfig::Builder::create()
                                                            .addColor(WHITE)
                                                            .addText("Hello, world!")
                                                            .addShadow(true)
                                                            .addRefEntity(transformEntity)
                                                            .addRefComponent("Tooltip")
                                                            .addRefValue("title")
                                                            .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                                                            .build())
                                                    .build();
        ui::UIElementTemplateNode uiDynamicTextEntry = ui::UIElementTemplateNode::Builder::create()
                                                    .addType(ui::UITypeEnum::OBJECT)
                                                    .addConfig(
                                                        ui::UIConfig::Builder::create()
                                                            .addColor(WHITE)
                                                            .addObject(textEntity)
                                                            .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                                                            .build())
                                                    .build();
        ui::UIElementTemplateNode uiAnimatedSpriteEntry = ui::UIElementTemplateNode::Builder::create()
                                                    .addType(ui::UITypeEnum::OBJECT)
                                                    .addConfig(
                                                        ui::UIConfig::Builder::create()
                                                            .addColor(WHITE)
                                                            .addObject(player)
                                                            .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                                                            .build())
                                                    .build();
        ui::UIElementTemplateNode uiTestInventoryEntry = ui::UIElementTemplateNode::Builder::create()
                                                    .addType(ui::UITypeEnum::OBJECT)
                                                    .addConfig(
                                                        ui::UIConfig::Builder::create()
                                                            .addColor(WHITE)
                                                            .addObject(testInventory)
                                                            .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                                                            .build())
                                                    .build();
        ui::UIElementTemplateNode uiTestInventoryColumn = ui::UIElementTemplateNode::Builder::create()
                                                    .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
                                                    .addConfig(
                                                        ui::UIConfig::Builder::create()
                                                            .addColor(YELLOW)
                                                            .addEmboss(2.f)
                                                            .addOutlineColor(BLUE)
                                                            // .addOutlineThickness(5.0f)
                                                            // .addMinWidth(500.f)
                                                            .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                                                            .build())
                                                    .addChild(getRandomRectDef())
                                                    .addChild(getRandomRectDef())
                                                    .addChild(uiTestInventoryEntry)
                                                    .build();
        ui::UIElementTemplateNode uiTextEntryContainer = ui::UIElementTemplateNode::Builder::create()
                                                             .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
                                                             .addConfig(
                                                                 ui::UIConfig::Builder::create()
                                                                     .addColor(GRAY)
                                                                     // .addOutlineThickness(2.0f)
                                                                     .addHover(true)
                                                                     .addButtonCallback([]()
                                                                                        { SPDLOG_DEBUG("Button callback triggered"); })
                                                                     .addOutlineColor(BLUE)
                                                                     // .addShadow(true)
                                                                     .addEmboss(4.f)
                                                                     .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                                                                     .build())
                                                             .addChild(uiTextEntry)
                                                             .build();

        ui::UIElementTemplateNode uiColumnDef = ui::UIElementTemplateNode::Builder::create()
                                                    .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
                                                    .addConfig(
                                                        ui::UIConfig::Builder::create()
                                                            .addColor(YELLOW)
                                                            .addEmboss(2.f)
                                                            .addOutlineColor(BLUE)
                                                            // .addOutlineThickness(5.0f)
                                                            // .addMinWidth(500.f)
                                                            .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                                                            .build())
                                                    .addChild(getRandomRectDef())
                                                    .addChild(getRandomRectDef())
                                                    .addChild(uiDynamicTextEntry)
                                                    .build();

        ui::UIElementTemplateNode uiRowDef = ui::UIElementTemplateNode::Builder::create()
                                                 .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
                                                 .addConfig(
                                                     ui::UIConfig::Builder::create()
                                                         .addColor(RED)
                                                         .addEmboss(2.f)
                                                         .addId("testRow")
                                                         .addHover(true)
                                                         .addButtonCallback([testConfig]()
                                                                            {
                    SPDLOG_DEBUG("Button callback triggered, renewing box alignment");
                    auto button = ui::box::GetUIEByID(globals::registry, uiBox, "testRow"); 
                    SPDLOG_DEBUG("Button ID: {}", globals::registry.get<ui::UIConfig>(button.value()).id.value());
                    // set text tooltip to a random string
                    auto &tooltip = globals::registry.get<ui::Tooltip>(transformEntity);
                    tooltip.title = random_utils::random_element<std::string>(
                        {"Hello", "World", "This is a test", "Testing 1, 2, 3", "Lorem ipsum dolor sit amet", "Random string"});

                    ui::box::RenewAlignment(globals::registry, uiBox); })
                                                         // .addMinHeight(500.f)
                                                         // .addOutlineThickness(5.0f)
                                                         // .addButtonCallback("testCallback")
                                                         // .addOnePress(true)
                                                         // .addFocusArgs((ui::FocusArgs{.redirect_focus_to = entt::entity{entt::null}}))
                                                         .addOutlineColor(BLUE)
                                                         .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_LEFT)
                                                         .build())
                                                 .addChild(uiColumnDef)
                                                 .addChild(getRandomRectDef())
                                                 .build();
        ui::UIElementTemplateNode consumablesRowDef = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(YELLOW)
                    .addEmboss(2.f)
                    .addOutlineColor(BLUE)
                    .addOutlineThickness(2.0f)
                    // .addMinWidth(500.f)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(getNewDynamicTextEntry("Consumables:", 20.f, 500.f, "bump;rainbow"))
            .addChild(uiTestInventoryEntry)
            .build();
        ui::UIElementTemplateNode spriteRowDef = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(YELLOW)
                    .addEmboss(2.f)
                    .addOutlineColor(BLUE)
                    .addOutlineThickness(2.0f)
                    // .addMinWidth(500.f)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(getNewDynamicTextEntry("Item sprite: ", 20.f, 500.f, "bump=6.0,8.0,0.9,0.2"))
            .addChild(uiAnimatedSpriteEntry)
            .build();
        ui::UIElementTemplateNode uiTestRootDef = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::ROOT)
            .addConfig(
                ui::UIConfig::Builder::create()
                    // .addMaxWidth(700.f)
                    .addColor(BLUE)
                    .addShadow(true)
                    // .addHover(true)
                    // .addButtonCallback("testCallback")
                    .addAlign(
                        transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(uiColumnDef)
        //   .addChild(uiDynamicTextEntry)
        //   .addChild(getRandomRectDef())
            .addChild(consumablesRowDef)
            .addChild(spriteRowDef)
            // .addChild(uiRowDef)
            .addChild(getNewTextEntry("HEY HEY!"))
            .build();

        uiBox = ui::box::Initialize(
            globals::registry,
            {.w = 200, .h = 200},
            uiTestRootDef,
            ui::UIConfig::Builder::create()
                .addRole(transform::InheritedProperties::Builder()
                             .addRoleType(transform::InheritedProperties::Type::RoleInheritor)
                             .addMaster(transformEntity)
                             .addLocationBond(transform::InheritedProperties::Sync::Strong)
                             .addRotationBond(transform::InheritedProperties::Sync::Strong)
                             .addAlignment(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_TOP)
                             .build())
                .build()

        );

        uiTextEntry.config.text = "This is a hover popup!";
        uiTextEntry.config.color = RED;
        uiTextEntry.config.ref_component.reset();
        uiTextEntry.config.ref_entity.reset();
        uiTextEntry.config.ref_value.reset();
        
        // hoverPopupUIBox = ui::box::Initialize(
        //     globals::registry,
        //     {.w = 200, .h = 200},
        //     uiTextEntry,
        //     ui::UIConfig::Builder::create()
        //         .addRole(transform::InheritedProperties::Builder()
        //                      .addRoleType(transform::InheritedProperties::Type::RoleInheritor)
        //                      .addMaster(transformEntity)
        //                      .addLocationBond(transform::InheritedProperties::Sync::Strong)
        //                      .addRotationBond(transform::InheritedProperties::Sync::Strong)
        //                      .addAlignment(transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT | transform::InheritedProperties::Alignment::VERTICAL_BOTTOM)
        //                      .build())
        //         .build());

        // LATER: figure out button UIE more precisely
        // LATER: when clicking on nested buttons, the outer button will sometimes trigger hover color intermittently

        // TODO: hover is currently required for clicking to work
        // TODO: elements should not be clikable by default, they seem to be
        // TODO: need to reflect rotation + scale in ui elements (optionally)
        // TODO: arguments to test
        /*
            button:

            choice = args.choice,
            chosen = args.chosen,
            focus_args = args.focus_args,
            func = args.func, -> just an update function

            slider:

            focus_args = {type = 'slider'}
            refresh_movement = true
            collideable = true

            toggle:

            button_dist = 0.2
            focus_args = {redirect_focus_to = true}


        */
        // LATER: bottom outline is sometimes jagged when buttons are scaled down
        //  LATER: use VBO & IBOS for rendering
        // LATER: ninepatch?

        // needed for correct disposal of transform components
        // TODO: move this to transform system init
        transform::registerDestroyListeners(globals::registry);

        // TODO: integrate new text system with ui (as object)
        // TODO: hover enlargement amount, whether to shake on hover, color change on hover, automatically recalculate button size (maybe scale it if necessary) after text size changes,
        // TODO: ui recalc function needs to be fixed. Not working at the moment.
        // TODO: hover scale amount should be customizable
        // TODO: h_popup and d_popup and alert
        // TODO: how to recenter text after it changes (refresh entire layout? or just center the text?)
        // TODO: how to use button delay
        // TODO: various ui elements (buttons, slider, toggle, radio button behavior, switch button with pips for selection, check box)
        // TODO: testing interactivity (click, drag, hover)
        // TODO: drag should probalby be replaced with custom function if ui is not meant to be moved (anything other than root)
        // TODO: popups for hover and drag
        // TODO: controller focus interactivity
        // TODO: apply, stop hover and release for ui elements

        // TODO: not sure how hover enlargement works yet.
        // REVIEW: to add jiggle on hover, just use node.methods->onHover with custom lamnda on the appropriate ui element's transform component.

        SPDLOG_DEBUG("{}", ui::box::DebugPrint(globals::registry, uiBox, 0));

        // auto testUI = ui::createTooltipUIBoxDef(globals::registry, {std::string("Tooltip"), std::string("tooltip")});
        // auto textTooltipUIBOX = ui::box::Initialize(globals::registry, {.w = 200, .h = 200}, testUI, ui::UIConfig::Builder::create().build());
        SetUpShaderUniforms();

        // auto &tooltipTransform = globals::registry.get<transform::Transform>(textTooltipUIBOX);
        // auto &tooltipNode = globals::registry.get<transform::GameObject>(textTooltipUIBOX);
        // auto &tooltipUIConfig = globals::registry.get<ui::UIConfig>(textTooltipUIBOX);

        // tooltipNode.state.dragEnabled = true;
        // tooltipNode.state.collisionEnabled = true;
        // tooltipNode.state.clickEnabled = true;
        // tooltipUIConfig.noMovementWhenDragged = true;
    }

    auto update(float delta) -> void
    {
        if (gameStarted == false)
            gameStarted = true;

        if (isGameOver)
            return;

        if (game::isPaused)
            return;

        particle::UpdateParticles(globals::registry, delta);
        shaders::updateAllShaderUniforms();
        
        auto textView = globals::registry.view<TextSystem::Text>();
        for (auto e : textView)
        {
            TextSystem::Functions::updateText(e, delta);
        }

        // update ui components
        // auto viewUI = globals::registry.view<ui::UIBoxComponent>();
        // for (auto e : viewUI)
        // {
        //     ui::box::Move(globals::registry, e, f);
        // }

        auto viewUIElement = globals::registry.view<ui::UIElementComponent>();
        for (auto e : viewUIElement)
        {
            ui::element::Update(globals::registry, e, delta);
        }

        // SPDLOG_DEBUG("{}", ui::box::DebugPrint(globals::registry, uiBox, 0));
    }

    auto draw(float dt) -> void
    {

        layer::Begin(); // clear all commands, we add new ones every frame

        // set up layers (needs to happen every frame)
        layer::AddClearBackground(background, util::getColor("brick_palette_red_resurrect"));
        layer::AddTextPro(background, "Title Scene", GetFontDefault(), 10, 30, {0, 0}, 0, 20, 1, util::getColor("WHITE"), 0);



        util::Profiler uiProfiler("UI Draw");
        // debug draw ui elements (draw ui boxes, will auto-propogate to children)
        auto viewUI = globals::registry.view<ui::UIBoxComponent>();
        for (auto e : viewUI)
        {
            ui::box::Draw(ui_layer, globals::registry, e);
        }

        util::Profiler transformProfiler("Transform Debug Draw");
        // do transform debug drawing
        auto view = globals::registry.view<transform::Transform>();
        for (auto e : view)
        {
            if (globals::drawDebugInfo)
                transform::DrawBoundingBoxAndDebugInfo(&globals::registry, e, ui_layer);
        }
        
        // draw object area (inventory comp)
        auto &objectArea = globals::registry.get<transform::GameObject>(testInventory);
        objectArea.drawFunction(ui_layer, globals::registry, testInventory);
        transformProfiler.Stop();

        // dynamic text
        auto textView = globals::registry.view<TextSystem::Text>();
        for (auto e : textView)
        {
            TextSystem::Functions::renderText(e, ui_layer, true);
        }

        // sprites with transform (including those in ui)
        layer::AddDrawTransformEntityWithAnimation(ui_layer, &globals::registry, player, globals::spriteAtlas, 0);
        uiProfiler.Stop();

        particle::DrawParticles(globals::registry, ui_layer);

        // we will draw to the sprites layer main canvas, modify it with a shader, then draw it to the screen
        // The reason we do this every frame is to allow position changes to the entities to be reflected in the draw commands
        // layer::AddDrawEntityWithAnimation(sprites, &globals::registry, player, 100 + sin(GetTime()) * 100, 100, globals::spriteAtlas, 0);
        // layer::AddDrawTransformEntityWithAnimation(sprites, &globals::registry, player, globals::spriteAtlas, 0);

        // clear the screen, not any canvas
        // renderer::ClearBackground(loading::getColor("brick_palette_red_resurrect"));

        util::Profiler drawProfiler("Draw Layers");
        layer::DrawLayerCommandsToSpecificCanvas(background, "main", nullptr);  // render the background layer commands to its main canvas
        layer::DrawLayerCommandsToSpecificCanvas(ui_layer, "main", nullptr);    // render the ui layer commands to its main canvas
        layer::DrawLayerCommandsToSpecificCanvas(sprites, "main", nullptr);     // render the sprite layer commands to its main canvas
        layer::DrawLayerCommandsToSpecificCanvas(finalOutput, "main", nullptr); // render the final output layer commands to its main canvas

        layer::Push(&globals::camera2D);

        // auto balatro = shaders::getShader("balatro_background");
        // shaders::TryApplyUniforms(balatro, globalShaderUniforms, "balatro_background");
        auto crt = shaders::getShader("crt");
        shaders::TryApplyUniforms(crt, globals::globalShaderUniforms, "crt");
        // auto shockwave = shaders::getShader("shockwave");
        // shaders::TryApplyUniforms(shockwave, globalShaderUniforms, "shockwave");
        // auto glitch = shaders::getShader("glitch");
        // shaders::TryApplyUniforms(glitch, globalShaderUniforms, "glitch");
        // auto wind = shaders::getShader("wind");
        // shaders::TryApplyUniforms(wind, globalShaderUniforms, "wind");
        // auto skew = shaders::getShader("3d_skew");
        // shaders::TryApplyUniforms(skew, globalShaderUniforms, "3d_skew");
        // auto squish = shaders::getShader("squish");
        // shaders::TryApplyUniforms(squish, globalShaderUniforms, "squish");
        auto peaches = shaders::getShader("peaches_background");
        shaders::TryApplyUniforms(peaches, globals::globalShaderUniforms, "peaches_background");
        // auto fade = shaders::getShader("fade");
        // shaders::TryApplyUniforms(fade, globalShaderUniforms, "fade");
        // auto fade_zoom = shaders::getShader("fade_zoom");
        // shaders::TryApplyUniforms(fade_zoom, globalShaderUniforms, "fade_zoom");
        // auto foil = shaders::getShader("foil");
        // shaders::TryApplyUniforms(foil, globalShaderUniforms, "foil");
        // auto holo = shaders::getShader("holo");
        // shaders::TryApplyUniforms(holo, globalShaderUniforms, "holo");
        // auto polychrome = shaders::getShader("polychrome");
        // shaders::TryApplyUniforms(polychrome, globalShaderUniforms, "polychrome");
        // auto negative_shine = shaders::getShader("negative_shine");
        // shaders::TryApplyUniforms(negative_shine, globalShaderUniforms, "negative_shine");
        // auto negative = shaders::getShader("negative");
        // shaders::TryApplyUniforms(negative, globalShaderUniforms, "negative");

        // 4. Render bg main, then sprite flash to the screen (if this was a different type of shader which could be overlapped, you could do that too)

        // layer::DrawCanvasToCurrentRenderTargetWithTransform(background, "main", 0, 0, 0, 1, 1, WHITE, peaches); // render the background layer main canvas to the screen
        // layer::DrawCanvasOntoOtherLayer(background, "main", finalOutput, "main", 0, 0, 0, 1, 1, WHITE); // render the background layer main canvas to the screen
        layer::DrawCanvasOntoOtherLayerWithShader(background, "main", finalOutput, "main", 0, 0, 0, 1, 1, WHITE, peaches); // render the background layer main canvas to the screen

        
        layer::DrawCanvasOntoOtherLayer(ui_layer, "main", finalOutput, "main", 0, 0, 0, 1, 1, WHITE); // render the ui layer main canvas to the screen

        layer::DrawCanvasOntoOtherLayer(sprites, "main", finalOutput, "main", 0, 0, 0, 1, 1, WHITE); // render the sprite layer main canvas to the screen


        // layer::DrawCanvasToCurrentRenderTargetWithTransform(ui_layer, "main", 0, 0, 0, 1, 1, WHITE);

        // layer::DrawCanvasToCurrentRenderTargetWithTransform(sprites, "flash", 0, 0, 0, 1, 1, WHITE);   // render the sprite layer flash canvas to the screen

        BeginDrawing();

        // clear screen
        ClearBackground(BLACK);

        layer::DrawCanvasToCurrentRenderTargetWithTransform(finalOutput, "main", 0, 0, 0, 1, 1, WHITE, crt); // render the final output layer main canvas to the screen

        rlImGuiBegin(); // Required: starts ImGui frame

        shaders::ShowShaderEditorUI(globals::globalShaderUniforms);

        rlImGuiEnd(); // Required: renders ImGui on top of Raylib

        // Display UPS and FPS
        const int fps = GetFPS(); // Get the current FPS
        DrawText(fmt::format("UPS: {} FPS: {}", main_loop::mainLoop.renderedUPS, GetFPS()).c_str(), 10, 10, 20, RED);

        EndDrawing();

        layer::Pop();

        drawProfiler.Stop();

        // BeginMode2D(globals::camera2D);

        // EndMode2D();

        layer::End();
    }

}