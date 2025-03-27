
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
#include "../systems/event_queue/new_event_system.hpp"
#include "../systems/event/event_system.hpp"
#include "../systems/sound/sound_system.hpp"
#include "../systems/text/textVer2.hpp"
#include "rlgl.h"

using std::pair;

#define SPINE_USE_STD_FUNCTION
#include "spine/spine.h"
#include "third_party/spine_impl/spine_raylib.hpp"
#include "spine/AnimationState.h"
#include "spine/Bone.h"

#include <map>

#include "util/common_headers.hpp"
#include "util/utilities.hpp"

#include "core/globals.hpp"

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
std::shared_ptr<layer::Layer> background; // background
std::shared_ptr<layer::Layer> sprites;    // sprites
std::shared_ptr<layer::Layer> ui_layer;         // ui
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

float transitionShaderPositionVar = 0.f;

shaders::ShaderUniformComponent globalShaderUniforms{}; // keep track of shader uniforms


namespace game
{

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
    
    ui::UIElementTemplateNode getRandomRectDef()
    {
        return ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::RECT_SHAPE)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(GREEN)
                    .addHover(true)
                    // .addOnePress(true)
                    .addButtonCallback([](){
                        SPDLOG_DEBUG("Button callback triggered");
                    })
                    .addWidth(Random::get<float>(20, 100))
                    .addHeight(Random::get<float>(20, 200))
                    .addMinWidth(200.f)
                    // .addOutlineThickness(2.0f)
                    // .addOutlineColor(BLUE)
                    // .addShadowColor(Fade(BLACK, 0.4f))
                    .addShadow(true)
                    // .addEmboss(4.f)
                    // .addOutlineThickness(2.0f)
                    .addOutlineColor(BLUE)
                    // .addShadow(true)
                    .build())
            .build();


        
        //TODO: templates for timer
        //TODO: how to chain timer calls optionally in a queue


    }
    
    // perform game-specific initialization here. This makes it easier to find all the initialization code
    // specific to a game project
    auto init() -> void
    {

        text = {
            // .rawText = fmt::format("[안녕하세요](color=red;shake=2,2). Here's a UID: [{}](color=red;pulse=0.9,1.1)", testUID),
            // .rawText = fmt::format("[안녕하세요](color=red;rotate=2.0,5;float). Here's a UID: [{}](color=red;pulse=0.9,1.1,3.0,4.0)", testUID),
            .rawText = fmt::format("[HEY HEY HEY Welcome to the game](rainbow;bump)\n[Testing testing](rainbow;pulse)"),
            .font = globals::translationFont,
            .fontSize = 50.0f,
            .wrapWidth = 500.0f,
            .position = Vector2{400, 300},
            .alignment = TextSystem::Text::Alignment::LEFT,
            .wrapMode = TextSystem::Text::WrapMode::WORD};

        text.onFinishedEffect = []()
        {
            spdlog::debug("Text effect finished.");

            // There is a brief flash of white when text changes. why?

            text.characters.clear();
            TextSystem::Functions::clearAllEffects(text);
            text.rawText = fmt::format("[some new text](rainbow;bump)");
            TextSystem::Functions::parseText(text);
            TextSystem::Functions::applyGlobalEffects(text, "pop=0.4,0.1,in;"); // ;
            TextSystem::Functions::updateText(text, 0.05f); // call update once to apply effects, prevent flashing
        };

        // init custom text system
        TextSystem::Functions::initEffects(text);
        TextSystem::Functions::parseText(text);

        // TextSystem::Functions::clearAllEffects(text);
        TextSystem::Functions::applyGlobalEffects(text, "pop=0.4,0.1,out;spin=4,0.1;"); // ;

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
        
        // load font
        // globals::fontData.font = LoadFontEx(util::getAssetPathUUIDVersion("fonts/en/slkscr.ttf").c_str(), 40, 0, 250);
        globals::fontData.font = globals::font;
        globals::fontData.fontScale = 1.0f;

        // create layer the size of the screen, with a main canvas the same size
        background = layer::CreateLayerWithSize(GetScreenWidth(), GetScreenHeight());
        sprites = layer::CreateLayerWithSize(GetScreenWidth(), GetScreenHeight());
        ui_layer = layer::CreateLayerWithSize(GetScreenWidth(), GetScreenHeight());
        finalOutput = layer::CreateLayerWithSize(GetScreenWidth(), GetScreenHeight());
        layer::AddCanvasToLayer(sprites, "flash"); // create a separate canvas for the flash effect

        // set camera to fill the screen
        globals::camera2D = {0};
        globals::camera2D.zoom = 1;
        globals::camera2D.target = {GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f};
        globals::camera2D.rotation = 0;
        globals::camera2D.offset = {GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f};

        // create entt::entity, give animation, which will update automatically thanks to animation system, which is updated in the main loop
        player = globals::registry.create();
        auto &anim = factory::emplaceAnimationQueue(globals::registry, player);
        anim.defaultAnimation = init::getAnimationObject("idle_animation");

        // massive container the size of the screen
        globals::gameWorldContainerEntity = transform::CreateGameWorldContainerEntity(&globals::registry, 0, 0, GetScreenWidth(), GetScreenHeight());
        auto &gameMapNode = globals::registry.get<transform::GameObject>(globals::gameWorldContainerEntity);
        gameMapNode.debug.debugText = "Map Container";

        transformEntity = transform::CreateOrEmplace(&globals::registry, globals::gameWorldContainerEntity, 0, 0, 200, 200);
        auto &node = globals::registry.get<transform::GameObject>(transformEntity);
        node.debug.debugText = "Parent";
        node.state.dragEnabled = true;
        //TODO: clicking + dragging doesn't work when hover is not enabled.
        node.state.hoverEnabled = true;
        node.state.collisionEnabled = true;
        node.state.clickEnabled = true;
        auto &transform = globals::registry.get<transform::Transform>(transformEntity);
        transform.setActualX(100);
        transform.setActualY(100);
        // transform.setActualR(45.f);
        transform::debugMode = true; // enable debug drawing of transforms

        //Testing ui
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
        transform::AssignRole(&globals::registry, childEntity, transform::InheritedProperties::Type::PermanentAttachment, transformEntity, transform::InheritedProperties::Sync::Strong, std::nullopt, transform::InheritedProperties::Sync::Strong, std::nullopt, Vector2{});
        auto &childRole = globals::registry.get<transform::InheritedProperties>(childEntity);
        childRole.flags->alignment = transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT | transform::InheritedProperties::Alignment::VERTICAL_CENTER | transform::InheritedProperties::Alignment::ALIGN_TO_INNER_EDGES;

        childEntity2 = transform::CreateOrEmplace(&globals::registry, globals::gameWorldContainerEntity, 0, 0, 40, 20);
        auto &childNode2 = globals::registry.get<transform::GameObject>(childEntity2);
        childNode2.debug.debugText = "Fixture 2";
        auto &childTransform2 = globals::registry.get<transform::Transform>(childEntity2);
        transform::AssignRole(&globals::registry, childEntity2, transform::InheritedProperties::Type::PermanentAttachment, transformEntity, transform::InheritedProperties::Sync::Strong, std::nullopt, transform::InheritedProperties::Sync::Strong, std::nullopt, Vector2{});
        auto &childRole2 = globals::registry.get<transform::InheritedProperties>(childEntity2);
        childRole2.flags->alignment = transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT | transform::InheritedProperties::Alignment::VERTICAL_CENTER;

        childEntity3 = transform::CreateOrEmplace(&globals::registry, globals::gameWorldContainerEntity, 0, 0, 200, 40);
        auto &childNode3 = globals::registry.get<transform::GameObject>(childEntity3);
        childNode3.debug.debugText = "Not fixture";
        auto &childTransform3 = globals::registry.get<transform::Transform>(childEntity3);
        transform::AssignRole(&globals::registry, childEntity3, transform::InheritedProperties::Type::RoleInheritor, transformEntity, transform::InheritedProperties::Sync::Strong, std::nullopt, transform::InheritedProperties::Sync::Strong, std::nullopt, Vector2{50.f, 50.f});
        auto &childRole3 = globals::registry.get<transform::InheritedProperties>(childEntity3);
        childRole3.flags->alignment = transform::InheritedProperties::Alignment::HORIZONTAL_LEFT | transform::InheritedProperties::Alignment::VERTICAL_BOTTOM;

        timer::TimerSystem::timer_every(4.0f, [](std::optional<float> f){

            particle::Particle particle{
                .velocity = Vector2{Random::get<float>(-200, 200), Random::get<float>(-200, 200)},
                .rotation = Random::get<float>(0, 360),
                .rotationSpeed = Random::get<float>(-180, 180),
                .scale = Random::get<float>(1, 10),
                .lifespan = Random::get<float>(1, 3),
                .color = random_utils::random_element<Color>({RED, GREEN, BLUE, YELLOW, ORANGE, PURPLE, PINK, BROWN, WHITE, BLACK})
            };

            //TODO: way to programatically modify frame times for animation

            particle::CreateParticle(globals::registry, 
                GetMousePosition(), 
                Vector2{10, 10}, 
                particle, 
                particle::ParticleAnimationConfig{.loop = true, .animationName ="sword_anim"});

        });
        
        auto &testConfig = globals::registry.emplace<ui::Tooltip>(transformEntity);
        testConfig.title = "Test Tooltip";
        
        reflection::registerMetaForComponent<ui::Tooltip>([](auto meta) {
            meta.type("Tooltip"_hs)  // Ensure type name matches the lookup string
                .template data<&ui::Tooltip::title>("title"_hs)
                .template data<&ui::Tooltip::text>("text"_hs);
        });

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
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build()
            )
            .build();
        ui::UIElementTemplateNode uiTextEntryContainer = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(GRAY)
                    // .addOutlineThickness(2.0f)
                    .addHover(true)
                    .addButtonCallback([](){
                        SPDLOG_DEBUG("Button callback triggered");
                    })
                    .addOutlineColor(BLUE)
                    // .addShadow(true)
                    .addEmboss(4.f)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build()
            )
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
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build()
            )
            .addChild(getRandomRectDef())
            .addChild(getRandomRectDef())
            .addChild(uiTextEntry)
            .build();
        
        ui::UIElementTemplateNode uiRowDef = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::VERTICAL_CONTAINER) 
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(RED)
                    .addEmboss(2.f)
                    
                    .addHover(true)
                    .addButtonCallback([](){
                        SPDLOG_DEBUG("Button callback triggered");
                    })
                    // .addMinHeight(500.f)
                    // .addOutlineThickness(5.0f)
                    // .addButtonCallback("testCallback")
                    // .addOnePress(true)
                    // .addFocusArgs((ui::FocusArgs{.funnel_to = entt::entity{entt::null}}))
                    .addOutlineColor(BLUE)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_LEFT)
                    .build()
            )
            .addChild(uiColumnDef)
            .addChild(getRandomRectDef())
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
                        transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER
                    )
                    .build()
            )       
            // .addChild(uiColumnDef)
            .addChild(uiRowDef)
            .addChild(uiTextEntryContainer)
            .addChild(getRandomRectDef())
            
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
                    .build()
                )
                .build()
        );
        
        //LATER: figure out button UIE more precisely
        //LATER: when clicking on nested buttons, the outer button will sometimes trigger hover color intermittently
        
        //TODO: hover is currently required for clicking to work
        //TODO: elements should not be clikable by default, they seem to be
        //TODO: need to reflect rotation + scale in ui elements (optionally)
        //TODO: arguments to test
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
            focus_args = {funnel_to = true}
            
            
        */
        //LATER: bottom outline is sometimes jagged
        // LATER: use VBO & IBOS for rendering
        //LATER: ninepatch?

        // needed for correct disposal of transform components
        transform::registerDestroyListeners(globals::registry);
        
        //TODO: hover scale amount should be customizable
        //TODO: h_popup and d_popup and alert
        //TODO: how to recenter text after it changes (refresh entire layout? or just center the text?)
        //TODO: is textDrawable used at all?
        //TODO: how to use button delay
        //TODO: various ui elements (buttons, sliders, etc.)
        //TODO: testing interactivity (click, drag, hover)
        //TODO: drag should probalby be replaced with custom function if ui is not meant to be moved (anything other than root)
        //TODO: popups for hover and drag
        //TODO: controller focus interactivity
        //TODO: apply, stop hover and release for ui elements
        
        SPDLOG_DEBUG("{}", ui::box::DebugPrint(globals::registry, uiBox, 0));

        
        // pre-load shader values for later use

        // screen transition
        globalShaderUniforms.set("screen_tone_transition", "in_out", 0.f);
        globalShaderUniforms.set("screen_tone_transition", "position", 0.0f);
        globalShaderUniforms.set("screen_tone_transition", "size", Vector2{32.f, 32.f});
        globalShaderUniforms.set("screen_tone_transition", "screen_pixel_size", Vector2{1.0f / GetScreenWidth(), 1.0f/ GetScreenHeight()});
        globalShaderUniforms.set("screen_tone_transition", "in_color", Vector4{0.0f, 0.0f, 0.0f, 1.0f});
        globalShaderUniforms.set("screen_tone_transition", "out_color", Vector4{1.0f, 1.0f, 1.0f, 1.0f});

        // background shader

        /*
        
            iTime	float	0.0 → ∞	Elapsed time in seconds. Drives animation. Use GetTime() or delta accumulation.
            texelSize	vec2	1.0 / screenSize	Inverse of resolution. E.g., vec2(1.0/1280.0, 1.0/720.0).
            polar_coordinates	bool	0 or 1	Whether to enable polar swirl distortion. 1 = ON.
            polar_center	vec2	0.0–1.0	Normalized UV center of polar distortion. (0.5, 0.5) = screen center.
            polar_zoom	float	0.1–5.0	Zooms radial distortion. 1.0 = normal. Lower = zoomed out, higher = intense warping.
            polar_repeat	float	1.0–10.0	Number of angular repetitions. Integer values give clean symmetry, higher = more spirals.
            spin_rotation	float	-50.0 to 50.0	Adds static phase offset to swirl. Negative = reverse direction.
            spin_speed	float	0.0–10.0+	Time-based swirl speed. 1.0 is normal. Higher values animate faster.
            offset	vec2	-1.0 to 1.0	Offsets center of swirl (in screen space units, scaled internally). (0,0) = centered.
            contrast	float	0.1–5.0	Intensity of color banding & separation. 1–2 is moderate. Too low = washed out, too high = posterized.
            spin_amount	float	0.0–1.0	Controls swirl based on distance from center. 0 = flat, 1 = full swirl.
            pixel_filter	float	50.0–1000.0	Pixelation size. Higher = smaller pixels. Use screen length / desired resolution.
            colour_1	vec4	Any RGBA	Base layer color. Dominates background.
            colour_2	vec4	Any RGBA	Middle blend color. Transitions with contrast and distance.
            colour_3	vec4	Any RGBA	Accent/outer color. Used at edges in the paint-like effect.
        */
        globalShaderUniforms.set("balatro_background", "texelSize", Vector2{1.0f / GetScreenWidth(), 1.0f / GetScreenHeight()}); // Dynamic resolution
        globalShaderUniforms.set("balatro_background", "polar_coordinates", 0.0f);
        globalShaderUniforms.set("balatro_background", "polar_center", Vector2{0.5f, 0.5f});
        globalShaderUniforms.set("balatro_background", "polar_zoom", 4.52f);
        globalShaderUniforms.set("balatro_background", "polar_repeat", 2.91f);
        globalShaderUniforms.set("balatro_background", "spin_rotation", 7.0205107f);
        globalShaderUniforms.set("balatro_background", "spin_speed", 6.8f);
        globalShaderUniforms.set("balatro_background", "offset", Vector2{0.0f, 0.0f});
        globalShaderUniforms.set("balatro_background", "contrast", 4.43f);
        globalShaderUniforms.set("balatro_background", "spin_amount", -0.09f);
        globalShaderUniforms.set("balatro_background", "pixel_filter", 300.0f);
        globalShaderUniforms.set("balatro_background", "colour_1", Vector4{0.020128006f, 0.0139369555f, 0.049019635f, 1.0f});
        globalShaderUniforms.set("balatro_background", "colour_2", Vector4{0.029411793f, 1.0f, 0.0f, 1.0f});
        globalShaderUniforms.set("balatro_background", "colour_3", Vector4{1.0f, 1.0f, 1.0f, 1.0f});
        shaders::registerUniformUpdate("balatro_background", [](Shader &shader){ // update iTime every frame
            globalShaderUniforms.set("balatro_background", "iTime", static_cast<float>(GetTime()));

            /*
                spin rotation:

                0.0	Neutral, baseline rotation
                1.0	Slight phase shift
                10.0	Visible but not overwhelming twist
                50.0+	Heavy spiral skewing, starts to distort hard
                Negative	Reverses swirl direction
                Fractional	Works fine – adds minor shifting
            */
            globalShaderUniforms.set("balatro_background", "spin_rotation", static_cast<float>(sin(GetTime() * 0.01f) * 13.0f));
        });

        // crt

        /*
            resolution	vec2	Typically {320, 180} to {1920, 1080}	Target screen resolution, required for scaling effects and sampling.
            iTime	float	0.0 → ∞	Time in seconds. Use GetTime(). Drives rolling lines, noise, chromatic aberration.
            scan_line_amount	float	0.0 – 1.0	Strength of horizontal scanlines. 0.0 = off, 1.0 = full effect.
            scan_line_strength	float	-12.0 – -1.0	How sharp the scanlines are. More negative = thinner/darker.
            pixel_strength	float	-4.0 – 0.0	How much pixel sampling blur is applied. 0.0 = sharp, -4.0 = blurry.
            warp_amount	float	0.0 – 5.0	Barrel distortion strength. Around 0.1 – 0.4 looks classic CRT.
            noise_amount	float	0.0 – 0.3	Random static per pixel. Good for a "dirty signal" look.
            interference_amount	float	0.0 – 1.0	Horizontal jitter/noise. Higher = more glitchy interference.
            grille_amount	float	0.0 – 1.0	Visibility of CRT RGB grille pattern. 0.1 – 0.4 is subtle, 1.0 is strong.
            grille_size	float	1.0 – 5.0	Scales the RGB grille. Smaller = tighter grille pattern.
            vignette_amount	float	0.0 – 2.0	Amount of darkening at corners. 1.0 is typical.
            vignette_intensity	float	0.0 – 1.0	Sharpness of vignette. 0.2 = soft falloff, 1.0 = harsh.
            aberation_amount	float	0.0 – 1.0	Chromatic aberration (RGB channel shift). Subtle at 0.1, heavy at 0.5+.
            roll_line_amount	float	0.0 – 1.0	Strength of vertical rolling white line. Retro TV effect.
            roll_speed	float	-8.0 – 8.0	Speed/direction of the rolling line. Positive = down, negative = up.
        */
        globalShaderUniforms.set("crt", "resolution", Vector2{static_cast<float>(GetScreenWidth()), static_cast<float>(GetScreenHeight())});
        shaders::registerUniformUpdate("crt", [](Shader &shader){ // update iTime every frame
            globalShaderUniforms.set("crt", "iTime", static_cast<float>(GetTime()));
        });
        globalShaderUniforms.set("crt", "roll_speed", 1.0f);
        globalShaderUniforms.set("crt", "resolution", Vector2{1280, 700});
        globalShaderUniforms.set("crt", "noise_amount", -0.02f);
        globalShaderUniforms.set("crt", "scan_line_amount", -0.17f);
        globalShaderUniforms.set("crt", "grille_amount", 0.15f);
        globalShaderUniforms.set("crt", "scan_line_strength", -4.89f);
        globalShaderUniforms.set("crt", "pixel_strength", -0.14f);
        globalShaderUniforms.set("crt", "vignette_amount", 0.24f);
        globalShaderUniforms.set("crt", "warp_amount", 0.06f);
        globalShaderUniforms.set("crt", "interference_amount", 1.4f);
        globalShaderUniforms.set("crt", "roll_line_amount", 0.04f);
        globalShaderUniforms.set("crt", "grille_size", 0.f);
        globalShaderUniforms.set("crt", "vignette_intensity", 0.11f);
        globalShaderUniforms.set("crt", "iTime", 113.47279f);
        globalShaderUniforms.set("crt", "aberation_amount", 0.93f);
        

        // shockwave
        globalShaderUniforms.set("shockwave", "resolution", Vector2{ (float)GetScreenWidth(), (float)GetScreenHeight() });
        globalShaderUniforms.set("shockwave", "strength", 0.18f);
        globalShaderUniforms.set("shockwave", "center", Vector2{0.5f, 0.5f});
        globalShaderUniforms.set("shockwave", "radius", 1.93f);
        globalShaderUniforms.set("shockwave", "aberration", -2.115f);
        globalShaderUniforms.set("shockwave", "width", 0.28f);
        globalShaderUniforms.set("shockwave", "feather", 0.415f);

        // glitch
        globalShaderUniforms.set("glitch", "resolution", Vector2{(float)GetScreenWidth(), (float)GetScreenHeight()});
        shaders::registerUniformUpdate("glitch", [](Shader &shader){ // update iTime every frame
            globalShaderUniforms.set("glitch", "iTime", static_cast<float>(GetTime()));
        });
        globalShaderUniforms.set("glitch", "shake_power", 0.03f);
        globalShaderUniforms.set("glitch", "shake_rate", 0.2f);
        globalShaderUniforms.set("glitch", "shake_speed", 5.0f);
        globalShaderUniforms.set("glitch", "shake_block_size", 30.5f);
        globalShaderUniforms.set("glitch", "shake_color_rate", 0.01f);

        // wind
        shaders::registerUniformUpdate("wind", [](Shader &shader){ // update iTime every frame
            globalShaderUniforms.set("wind", "iTime", static_cast<float>(GetTime()));
        });
        globalShaderUniforms.set("wind", "speed", 1.0f);
        globalShaderUniforms.set("wind", "minStrength", 0.05f);
        globalShaderUniforms.set("wind", "maxStrength", 0.1f);
        globalShaderUniforms.set("wind", "strengthScale", 100.0f);
        globalShaderUniforms.set("wind", "interval", 3.5f);
        globalShaderUniforms.set("wind", "detail", 2.0f);
        globalShaderUniforms.set("wind", "distortion", 1.0f);
        globalShaderUniforms.set("wind", "heightOffset", 0.0f);
        globalShaderUniforms.set("wind", "offset", 1.0f); // vary per object

        // pseudo 3d skew
        shaders::registerUniformUpdate("3d_skew", [](Shader &shader) {
            globalShaderUniforms.set("3d_skew", "iTime", static_cast<float>(GetTime()));
            globalShaderUniforms.set("3d_skew", "mouse_screen_pos", GetMousePosition());
            globalShaderUniforms.set("3d_skew", "resolution", Vector2{
                static_cast<float>(GetScreenWidth()),
                static_cast<float>(GetScreenHeight())
            });
        });    
        // --- Projection parameters (from your log) ---
        globalShaderUniforms.set("3d_skew", "fov", -0.39f);              // From runtime dump
        globalShaderUniforms.set("3d_skew", "x_rot", 0.0f);              // No X tilt
        globalShaderUniforms.set("3d_skew", "y_rot", 0.0f);              // No Y orbit
        globalShaderUniforms.set("3d_skew", "inset", 0.0f);              // No edge compression    
        // --- Interaction dynamics ---
        globalShaderUniforms.set("3d_skew", "hovering", 0.07f);          // From your log
        globalShaderUniforms.set("3d_skew", "rand_trans_power", 0.09f);  // From your log
        globalShaderUniforms.set("3d_skew", "rand_seed", 3.1415f);       // Per-object offset
        globalShaderUniforms.set("3d_skew", "rotation", 0.0f);           // No UV twist
        globalShaderUniforms.set("3d_skew", "cull_back", 0.0f);          // Disable backface culling    
        // --- Geometry settings ---
        float drawWidth = static_cast<float>(GetScreenWidth());
        float drawHeight = static_cast<float>(GetScreenHeight());
        globalShaderUniforms.set("3d_skew", "regionRate", Vector2{
            drawWidth / drawWidth, // = 1.0
            drawHeight / drawHeight // = 1.0
        });
        globalShaderUniforms.set("3d_skew", "pivot", Vector2{ 0.0f, 0.0f }); // Al

        // squish
        globalShaderUniforms.set("squish", "up_left", Vector2{0.0f, 0.0f});
        globalShaderUniforms.set("squish", "up_right", Vector2{1.0f, 0.0f});
        globalShaderUniforms.set("squish", "down_right", Vector2{1.0f, 1.0f});
        globalShaderUniforms.set("squish", "down_left", Vector2{0.0f, 1.0f});
        globalShaderUniforms.set("squish", "plane_size", Vector2{(float)GetScreenWidth(), (float)GetScreenHeight()});
        shaders::registerUniformUpdate("squish", [](Shader &shader) {
            // occilate x and y
            globalShaderUniforms.set("squish", "squish_x", (float) sin(GetTime() * 0.5f) * 0.1f);
            globalShaderUniforms.set("squish", "squish_Y", (float) cos(GetTime() * 0.2f) * 0.1f);
        });   


        // peaches background
        std::vector<Color> myPalette = {
            WHITE,
            BLUE, 
            GREEN,
            RED,
            YELLOW,
            PURPLE
        };

        globalShaderUniforms.set("peaches_background", "resolution", Vector2{ (float)GetScreenWidth(), (float)GetScreenHeight() });
        shaders::registerUniformUpdate("peaches_background", [](Shader& shader) {
            globalShaderUniforms.set("peaches_background", "iTime", (float)GetTime());
        });
        globalShaderUniforms.set("peaches_background", "resolution", Vector2{ (float)GetScreenWidth(), (float)GetScreenHeight() });
        // === Blob settings ===
        globalShaderUniforms.set("peaches_background", "blob_count", 9.58f);
        globalShaderUniforms.set("peaches_background", "blob_spacing", 0.29f);
        globalShaderUniforms.set("peaches_background", "shape_amplitude", 0.135f); // <- animated
        // === Noise + distortion ===
        globalShaderUniforms.set("peaches_background", "distortion_strength", 1.28f);
        globalShaderUniforms.set("peaches_background", "noise_strength", 0.13f);
        globalShaderUniforms.set("peaches_background", "noise_blend_value", -0.53f);
        globalShaderUniforms.set("peaches_background", "time_noise_weight", -1.64f);
        globalShaderUniforms.set("peaches_background", "stripe_noise_weight", -0.57f);
        // === Edge behavior ===
        globalShaderUniforms.set("peaches_background", "edge_softness_min", 0.33f);
        globalShaderUniforms.set("peaches_background", "edge_softness_max", 0.67f);
        // === Visual shaping ===
        globalShaderUniforms.set("peaches_background", "cl_shift", 0.15f);
        globalShaderUniforms.set("peaches_background", "radial_falloff", -0.9f);
        globalShaderUniforms.set("peaches_background", "wave_strength", 2.5f);
        globalShaderUniforms.set("peaches_background", "highlight_gain", -2.04f);
        // === Color ===
        globalShaderUniforms.set("peaches_background", "colorTint", Vector3{ 0.3f, 0.4f, 0.9f }); // <- animated





        // globalShaderUniforms.set("peaches_background", "blob_count", 24.0f);
        // globalShaderUniforms.set("peaches_background", "blob_spacing", 0.045f);
        // globalShaderUniforms.set("peaches_background", "shape_amplitude", 0.035f);
        // globalShaderUniforms.set("peaches_background", "distortion_strength", 4.0f);
        // globalShaderUniforms.set("peaches_background", "cl_shift", 0.3f);
        // globalShaderUniforms.set("peaches_background", "radial_falloff", 0.8f);
        // globalShaderUniforms.set("peaches_background", "wave_strength", 4.8f);
        // globalShaderUniforms.set("peaches_background", "highlight_gain", 1.5f);
        // globalShaderUniforms.set("peaches_background", "noise_strength", 0.16f);
        // globalShaderUniforms.set("peaches_background", "edge_softness_min", 0.05f);
        // globalShaderUniforms.set("peaches_background", "edge_softness_max", 0.85f);

        // globalShaderUniforms.set("peaches_background", "blob_count", 6.0f);
        // globalShaderUniforms.set("peaches_background", "blob_spacing", 0.15f);
        // globalShaderUniforms.set("peaches_background", "shape_amplitude", 0.015f);
        // globalShaderUniforms.set("peaches_background", "distortion_strength", 1.5f);
        // globalShaderUniforms.set("peaches_background", "cl_shift", 0.1f);
        // globalShaderUniforms.set("peaches_background", "radial_falloff", 0.2f);
        // globalShaderUniforms.set("peaches_background", "wave_strength", 2.0f);
        // globalShaderUniforms.set("peaches_background", "highlight_gain", 1.1f);
        // globalShaderUniforms.set("peaches_background", "noise_strength", 0.05f);
        // globalShaderUniforms.set("peaches_background", "edge_softness_min", 0.2f);
        // globalShaderUniforms.set("peaches_background", "edge_softness_max", 0.6f);

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

    }

    auto draw(float dt) -> void
    {

        layer::Begin(); // clear all commands, we add new ones every frame

        // set up layers (needs to happen every frame)
        layer::AddClearBackground(background, util::getColor("brick_palette_red_resurrect"));
        layer::AddTextPro(background, "Title Scene", GetFontDefault(), 10, 30, {0, 0}, 0, 20, 1, util::getColor("WHITE"), 0);

        util::Profiler transformProfiler("Transform Debug Draw");
        // do transform debug drawing
        auto view = globals::registry.view<transform::Transform>(entt::exclude<ui::UIElementComponent, ui::UIBoxComponent>);
        for (auto e : view)
        {
            transform::DrawBoundingBoxAndDebugInfo(&globals::registry, e, ui_layer);
        }
        transformProfiler.Stop();

        util::Profiler uiProfiler("UI Draw");
        // debug draw ui elements (draw ui boxes, will auto-propogate to children)
        auto viewUI = globals::registry.view<ui::UIBoxComponent>();
        for (auto e : viewUI)
        {
            ui::box::Draw(ui_layer, globals::registry, e);
        }
        uiProfiler.Stop();

        particle::DrawParticles(globals::registry, ui_layer);
        
        // we will draw to the sprites layer main canvas, modify it with a shader, then draw it to the screen
        // The reason we do this every frame is to allow position changes to the entities to be reflected in the draw commands
        layer::AddDrawEntityWithAnimation(sprites, &globals::registry, player, 100 + sin(GetTime()) * 100, 100, globals::spriteAtlas, 0);

        // clear the screen, not any canvas
        // renderer::ClearBackground(loading::getColor("brick_palette_red_resurrect"));

        util::Profiler drawProfiler("Draw Layers");
        layer::DrawLayerCommandsToSpecificCanvas(background, "main", nullptr); // render the background layer commands to its main canvas
        layer::DrawLayerCommandsToSpecificCanvas(sprites, "main", nullptr); // render the sprite layer commands to its main canvas
        layer::DrawLayerCommandsToSpecificCanvas(sprites, "flash", nullptr); // render the sprite layer commands to its flash canvas
        layer::DrawLayerCommandsToSpecificCanvas(ui_layer, "main", nullptr); // render the ui layer commands to its main canvas
        layer::DrawLayerCommandsToSpecificCanvas(finalOutput, "main", nullptr); // render the final output layer commands to its main canvas

        layer::Push(&globals::camera2D);

        
        auto balatro = shaders::getShader("balatro_background");
        shaders::TryApplyUniforms(balatro, globalShaderUniforms, "balatro_background");
        auto crt = shaders::getShader("crt");
        shaders::TryApplyUniforms(crt, globalShaderUniforms, "crt");
        auto shockwave = shaders::getShader("shockwave");
        shaders::TryApplyUniforms(shockwave, globalShaderUniforms, "shockwave");
        auto glitch = shaders::getShader("glitch");
        shaders::TryApplyUniforms(glitch, globalShaderUniforms, "glitch");
        auto wind = shaders::getShader("wind");
        shaders::TryApplyUniforms(wind, globalShaderUniforms, "wind");
        auto skew = shaders::getShader("3d_skew");
        shaders::TryApplyUniforms(skew, globalShaderUniforms, "3d_skew");
        auto squish = shaders::getShader("squish");
        shaders::TryApplyUniforms(squish, globalShaderUniforms, "squish");
        auto peaches = shaders::getShader("peaches_background");
        shaders::TryApplyUniforms(peaches, globalShaderUniforms, "peaches_background");

        // 4. Render bg main, then sprite flash to the screen (if this was a different type of shader which could be overlapped, you could do that too)
        

        
        // layer::DrawCanvasToCurrentRenderTargetWithTransform(background, "main", 0, 0, 0, 1, 1, WHITE, balatro); // render the background layer main canvas to the screen
        // layer::DrawCanvasOntoOtherLayer(background, "main", finalOutput, "main", 0, 0, 0, 1, 1, WHITE); // render the background layer main canvas to the screen
        layer::DrawCanvasOntoOtherLayerWithShader(background, "main", finalOutput, "main", 0, 0, 0, 1, 1, WHITE, peaches); // render the background layer main canvas to the screen
        
        layer::DrawCanvasOntoOtherLayer(sprites, "main", finalOutput, "main", 0, 0, 0, 1, 1, WHITE); // render the sprite layer main canvas to the screen

        layer::DrawCanvasOntoOtherLayer(ui_layer, "main", finalOutput, "main", 0, 0, 0, 1, 1, WHITE); // render the ui layer main canvas to the screen

        // layer::DrawCanvasToCurrentRenderTargetWithTransform(ui_layer, "main", 0, 0, 0, 1, 1, WHITE); 

        // layer::DrawCanvasToCurrentRenderTargetWithTransform(sprites, "flash", 0, 0, 0, 1, 1, WHITE);   // render the sprite layer flash canvas to the screen

        BeginDrawing();
        
        // clear screen
        ClearBackground(BLACK);

        layer::DrawCanvasToCurrentRenderTargetWithTransform(finalOutput, "main", 0, 0, 0, 1, 1, WHITE, crt); // render the final output layer main canvas to the screen

        rlImGuiBegin();  // Required: starts ImGui frame

        shaders::ShowShaderEditorUI(globalShaderUniforms);

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