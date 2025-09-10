#pragma once

#include <tuple>

#include "core/globals.hpp"
#include "forward.hpp"
#include "systems/localization/localization.hpp"
#include "types.hpp"
#include "util/common_headers.hpp"
#include "util/utilities.hpp"
#include "systems/text/textVer2.hpp"
#include "systems/text/static_ui_text.hpp"
#include "systems/timer/timer.hpp"
#include "systems/scripting/binding_recorder.hpp"
#include "systems/ai/ai_system.hpp"
#include "systems/nine_patch/nine_patch_baker.hpp"

#include "systems/ui/ui.hpp"
#include "core/misc_fuctions.hpp"


namespace ui_defs
{
    // randomly sized rectangle (rounded)
    inline auto getRandomRectDef() -> ui::UIElementTemplateNode
    {
        NPatchInfo nPatchinfo;
        Texture2D npatchTexture;
        std::tie(nPatchinfo, npatchTexture) = animation_system::getNinepatchUIBorderInfo("rounded_rect_very_small.png");
        
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
                    .addStylingType(ui::UIStylingType::NINEPATCH_BORDERS)
                    .addNPatchInfo(nPatchinfo)
                    .addNPatchSourceTexture(npatchTexture)
                    // .addOutlineThickness(5.0f)
                    // .addShadowColor(Fade(BLACK, 0.4f))
                    .addShadow(true)
                    // .addEmboss(4.f)
                    // .addOutlineThickness(2.0f)
                    // .addOutlineColor(BLUE)
                    // .addShadow(true)
                    .build())
            .build();

        // TODO: templates for timer
        // TODO: how to chain timer calls optionally in a queue
    }
    
    
    // returns a UIElementTemplateNode for UITypeEnum::TEXT (no container)
    inline auto getNewTextEntry(std::string text, std::optional<entt::entity> refEntity = std::nullopt, std::optional<std::string> refComponent = std::nullopt, std::optional<std::string> refValue = std::nullopt) -> ui::UIElementTemplateNode {
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

    inline auto textDividerTestBoxDef() -> ui::UIElementTemplateNode
    {
        
        // make a row
    }
    
    //TODO: use get_value_callback and onStringContentUpdatedViaCallback to update text, not reflection. It's just easier
    inline auto getNewDynamicTextEntry(std::string text, float fontSize, std::optional<float> wrapWidth, std::optional<std::string> textEffect = std::nullopt, std::optional<entt::entity> refEntity = std::nullopt, std::optional<std::string> refComponent = std::nullopt, std::optional<std::string> refValue = std::nullopt) -> ui::UIElementTemplateNode {

        TextSystem::Text textData = {
            // .rawText = fmt::format("[안녕하세요](color=red;shake=2,2). Here's a UID: [{}](color=red;pulse=0.9,1.1)", testUID),
            // .rawText = fmt::format("[안녕하세요](color=red;rotate=2.0,5;float). Here's a UID: [{}](color=red;pulse=0.9,1.1,3.0,4.0)", testUID),
            
            .rawText = text,
            .fontData = localization::getFontData(),
            .fontSize = fontSize,
            .wrapEnabled = wrapWidth ? true : false,
            .wrapWidth = wrapWidth.value_or(0.0f),
            .alignment = TextSystem::Text::Alignment::LEFT,
            .wrapMode = TextSystem::Text::WrapMode::WORD
        };

        // resize when text is updated (applies to ui)
        textData.onStringContentUpdatedOrChangedViaCallback = [](entt::entity textEntity) {
            // get master
            auto &role = globals::registry.get<transform::InheritedProperties>(textEntity);

            if (!globals::registry.valid(role.master)) return;

            auto &masterTransform = globals::registry.get<transform::Transform>(role.master);
            
            TextSystem::Functions::resizeTextToFit(textEntity, masterTransform.getActualW(), masterTransform.getActualH());
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

        // timer::TimerSystem::timer_every(3.f, [textEntity](std::optional<float> f) {
        //     TextSystem::Functions::debugPrintText(textEntity);
        // });

        auto node = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::OBJECT)
            .addConfig(configBuilder.build());

        return node.build();        
    }
    
    // example of a button group with three buttons which are mutually exclusive
    inline auto getButtonGroupRowDef() -> ui::UIElementTemplateNode
    {
        //TODO: unify all styles?
        NPatchInfo nPatchinfo;
        Texture2D npatchTexture;
        std::tie(nPatchinfo, npatchTexture) = animation_system::getNinepatchUIBorderInfo("rounded_rect_small.png");

        auto button = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(WHITE)
                    .addText("Button")
                    .addShadow(true)
                    .addMinWidth(100.f)
                    .addMinHeight(100.f)
                    .addHover(true)
                    .addChoice(true) // radio button
                    .addStylingType(ui::UIStylingType::NINEPATCH_BORDERS)
                    .addNPatchInfo(nPatchinfo)
                    .addNPatchSourceTexture(npatchTexture)
                    // .addOnePress(true)
                    .addButtonCallback([]()
                                    { SPDLOG_DEBUG("Button callback triggered"); })
                    // .addOutlineThickness(2.0f)
                    // .addOutlineColor(BLUE)
                    // .addEmboss(4.f)
                    // .addShadow(true)
                    .build())
            .build();
            
        
        
        auto row = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(YELLOW)
                    // .addEmboss(2.f)
                    // .addOutlineColor(BLUE)
                    .addPadding(20.f)
                    .addStylingType(ui::UIStylingType::NINEPATCH_BORDERS)
                    .addNPatchInfo(nPatchinfo)
                    .addNPatchSourceTexture(npatchTexture)
                    // .addOutlineThickness(5.0f)
                    // .addMinWidth(500.f)
                    .addGroup("tabGroup")
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(button)
            .addChild(button)
            .addChild(button)
            .build();
            
        return row;
    }

    inline auto getTextFromString(std::string text) -> ui::UIElementTemplateNode
    {
        
        auto parseResult = static_ui_text_system::parseText(text);

        auto rows = parseResult.lines.size();

        vector<ui::UIElementTemplateNode> textRowDefs{};

        for (auto i = 0; i < rows; i++) {
            auto row = parseResult.lines[i];
            auto segments = row.segments.size();

            vector<ui::UIElementTemplateNode> textSegmentDefs{};
            
            using static_ui_text_system::StaticStyledTextSegmentType;
            for (auto j = 0; j < segments; j++) {
                auto segment = row.segments[j];
                
                if (segment.type == StaticStyledTextSegmentType::IMAGE) {
                    // handle case where this is an image, not text
                    // [img](uuid=gear.png;scale=0.8;fg=WHITE;shadow=false)
                    auto uuid = std::get<std::string>(segment.attributes["uuid"]);
                    auto scale = segment.attributes.find("scale") != segment.attributes.end() ? std::stof(std::get<std::string>(segment.attributes["scale"])) : 1.0f;
                    auto fgColorString = segment.attributes.find("fg") != segment.attributes.end() ? std::get<std::string>(segment.attributes["fg"]) : "WHITE";
                    auto shadow = segment.attributes.find("shadow") != segment.attributes.end() ? (std::get<std::string>(segment.attributes["shadow"]) == "true" ? true : false) : false;
                    auto fgColor = util::getColor(fgColorString);
                    
                    // now create a static animation object with uuid
                    auto imageObject = animation_system::createAnimatedObjectWithTransform(uuid, true, 0, 0);
                    auto &gameObjectComp = globals::registry.get<transform::GameObject>(imageObject);
                    if (shadow == false) gameObjectComp.shadowDisplacement.reset();
                    
                    std::optional<std::string> elementID{std::nullopt};
                    
                    if (auto it = segment.attributes.find("elementID"); it != segment.attributes.end()) {
                        elementID = std::get<std::string>(it->second);
                    }
                    
                    // add to an object node
                    auto imageDef = ui::UIElementTemplateNode::Builder::create()
                        .addType(ui::UITypeEnum::OBJECT)
                        .addConfig(
                            ui::UIConfig::Builder::create()
                                .addObject(imageObject)
                                .addColor(fgColor)
                                .addScale(scale)
                                .addShadow(shadow)
                                .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                                .build())
                        .build();
                        
                    if (elementID) {
                        imageDef.config.id = *elementID;
                    }
                    textSegmentDefs.push_back(imageDef);
                    
                    continue;
                }
                else if (segment.type == StaticStyledTextSegmentType::ANIMATION) {
                    
                    // [anim](uuid=gear.png;scale=0.8;fg=WHITE;shadow=false)
                    auto uuid = std::get<std::string>(segment.attributes["uuid"]);
                    auto scale = segment.attributes.find("scale") != segment.attributes.end() ? std::stof(std::get<std::string>(segment.attributes["scale"])) : 1.0f;
                    auto fgColorString = segment.attributes.find("fg") != segment.attributes.end() ? std::get<std::string>(segment.attributes["fg"]) : "WHITE";
                    auto shadow = segment.attributes.find("shadow") != segment.attributes.end() ? (std::get<std::string>(segment.attributes["shadow"]) == "true" ? true : false) : false;
                    auto fgColor = util::getColor(fgColorString);
                    
                    std::optional<std::string> elementID{std::nullopt};
                    
                    if (auto it = segment.attributes.find("elementID"); it != segment.attributes.end()) {
                        elementID = std::get<std::string>(it->second);
                    }
                    
                    // now create a animation object with uuid (animations.json)
                    auto imageObject = animation_system::createAnimatedObjectWithTransform(uuid, false, 0, 0);
                    
                    
                    auto &gameObjectComp = globals::registry.get<transform::GameObject>(imageObject);
                    if (shadow == false) gameObjectComp.shadowDisplacement.reset();
                    
                    // add to an object node
                    auto imageDef = ui::UIElementTemplateNode::Builder::create()
                        .addType(ui::UITypeEnum::OBJECT)
                        .addConfig(
                            ui::UIConfig::Builder::create()
                                .addObject(imageObject)
                                .addColor(fgColor)
                                .addScale(scale)
                                .addShadow(shadow)
                                .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                                .build())
                        .build();
                        
                    if (elementID) {
                        imageDef.config.id = *elementID;
                    }
                    textSegmentDefs.push_back(imageDef);
                    
                    continue;
                }


                auto textSegmentDef = getNewTextEntry(segment.text);
                
                std::optional<std::string> elementID{std::nullopt};
                    
                if (auto it = segment.attributes.find("elementID"); it != segment.attributes.end()) {
                    elementID = std::get<std::string>(it->second);
                }
                
                if (elementID) {
                    textSegmentDef.config.id = *elementID;
                }

                if (segment.attributes.find("color") != segment.attributes.end()) {
                    auto colorString = std::get<std::string>(segment.attributes["color"]);

                    auto color = util::getColor(colorString);

                    textSegmentDef.config.color = color;
                }
                if (segment.attributes.find("background") != segment.attributes.end()) {
                    auto backgroundString = std::get<std::string>(segment.attributes["background"]);

                    auto color = util::getColor(backgroundString);

                    // wrap in a horizontal container to produce background
                    auto wrapperDef = ui::UIElementTemplateNode::Builder::create()
                        .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
                        .addConfig(
                            ui::UIConfig::Builder::create()
                                .addColor(color)
                                .addPadding(10.f)
                                .addEmboss(2.f)
                                .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                                .build())
                        .addChild(textSegmentDef)
                        .build();

                    textSegmentDef = wrapperDef;
                }

                textSegmentDefs.push_back(textSegmentDef);
            }

            auto textRowDef = ui::UIElementTemplateNode::Builder::create()
                .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
                .addConfig(
                    ui::UIConfig::Builder::create()
                        // .addColor(WHITE)
                        .addPadding(1.f)
                        .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_LEFT | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                        .build());

            for (auto &segmentDef : textSegmentDefs) {
                textRowDef.addChild(segmentDef);
            }

            textRowDefs.push_back(textRowDef.build());
        }

        // add the final to a vertical container
        auto textDef = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    // .addColor(WHITE)
                    .addPadding(0.0f)
                    .addMaxWidth(300.f)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build());
        
        for (auto &rowDef : textRowDefs) {
            textDef.addChild(rowDef);
        }

        return textDef.build();
    }


    inline auto putCodedTextBetweenDividers(std::string text, std::string dividerToUse) -> ui::UIElementTemplateNode
    {
        auto dividerAnimRight = animation_system::createAnimatedObjectWithTransform(dividerToUse, true, 0, 0);
        auto codedTextDef = getTextFromString(text);
        auto dividerAnimLeft = animation_system::createAnimatedObjectWithTransform(dividerToUse, true, 0, 0);
        auto &animQueue = globals::registry.get<AnimationQueueComponent>(dividerAnimRight);
        animQueue.defaultAnimation.flippedHorizontally = true; // flip the right divider

        //TODO: disable shadow on dividers

        auto dividerUIObjectLeft = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::OBJECT)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addObject(dividerAnimLeft)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_LEFT | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .build();
        
        auto dividerUIObjectRight = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::OBJECT)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addObject(dividerAnimRight)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .build();

        auto row = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    // .addColor(WHITE)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(dividerUIObjectLeft)
            .addChild(codedTextDef)
            .addChild(dividerUIObjectRight)
            .build();

        return row;
    }
    
    inline auto wrapEntityInsideObjectElement(entt::entity entity) -> ui::UIElementTemplateNode{
        auto objectElement = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::OBJECT)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addObject(entity)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .build();
            
        return objectElement;
    }
    
    inline auto moveInventoryItemToNewTile(entt::entity released, entt::entity releasedOn) -> void
    {
        auto &uiConfigOnReleased = globals::registry.get<ui::UIConfig>(releasedOn);
        uiConfigOnReleased.color = globals::uiInventoryOccupied;
        
        transform::AssignRole(&globals::registry, released, transform::InheritedProperties::Type::RoleInheritor, releasedOn, std::nullopt, std::nullopt, transform::InheritedProperties::Sync::Weak);

        game::centerInventoryItemOnTargetUI(released, releasedOn);
        
        auto &inventoryTile = globals::registry.get<ui::InventoryGridTileComponent>(releasedOn);
        inventoryTile.item = released;
    }

    inline auto getCheckboxExample() -> ui::UIElementTemplateNode
    {
        auto checkboxImage = animation_system::createAnimatedObjectWithTransform("checkmark.png", true, 0, 0);

        auto checkbox = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::OBJECT)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addObject(checkboxImage)
                    // .addColor(WHITE)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .build();
        
        auto row = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(GRAY)
                    .addEmboss(2.f)
                    .addMaxHeight(100.f)
                    .addMaxWidth(100.f)
                    .addHover(true)
                    
                    .addButtonCallback([checkboxImage]()
                                    { SPDLOG_DEBUG("Button callback triggered"); 
                                        // disable image
                                        auto &aqc = globals::registry.get<AnimationQueueComponent>(checkboxImage);
                                        
                                        aqc.noDraw = !aqc.noDraw;
                                    })
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(checkbox)
            .build();

        return row;
    }

    inline auto getProgressBarRoundedRectExample() -> ui::UIElementTemplateNode
    {
        auto progressBarTextMoving = getNewDynamicTextEntry("Progress Bar (vertices)", 20.f, std::nullopt, "pulse=0.9,1.1");
        static float progressValueExample = 0.f;
        timer::TimerSystem::timer_every(0.1f, [](std::optional<float> f) {
            
            // set value based on sin of time, 0 < value < 1
            progressValueExample = (std::sin(GetTime()) + 1.f) / 2.f;
            
        });
        auto progressBar = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(GRAY)
                    .addProgressBarMaxValue(100.f)
                    // .addEmboss(2.f)
                    .addMinHeight(50.f)
                    .addMinWidth(500.f)
                    .addProgressBar(true)
                    .addProgressBarEmptyColor(WHITE)
                    .addProgressBarFullColor(BLUE)
                    .addProgressBarFetchValueLamnda([](entt::entity e)
                                    { 
                                        return progressValueExample;
                                    })
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(progressBarTextMoving)
            .build();
        
        return progressBar;
    }

    inline auto getSliderNinepatchExample() -> ui::UIElementTemplateNode
    {
        auto progressBarTextMoving = getNewDynamicTextEntry("Progress Bar (9-patch)", 20.f, std::nullopt, "wiggle=12,15,0.5");
        static float progressValueExample9Patch = 0.f;
        timer::TimerSystem::timer_every(0.1f, [](std::optional<float> f) {
            
            // set value based on sin of time, 0 < value < 1
            progressValueExample9Patch = (std::sin(GetTime()) + 1.f) / 2.f;
            
        });
        
        NPatchInfo nPatchinfo;
        Texture2D npatchTexture;
        std::tie(nPatchinfo, npatchTexture) = animation_system::getNinepatchUIBorderInfo("rounded_rect_very_small.png");
        
        auto exampleNine = nine_patch::BakeNinePatchFromSprites(
            nine_patch::NineSliceNames{
                "roguelike_ui7.png", "roguelike_ui8.png", "roguelike_ui9.png",
                "roguelike_ui13.png",  "roguelike_ui2.png", "roguelike_ui15.png",
                "roguelike_ui19.png", "roguelike_ui20.png", "roguelike_ui21.png"
            },
            /*scale=*/1.0f
        );
        
        // Choose what to tile at *draw-time*:
        nine_patch::NPatchTiling til{};
        til.centerX = true;         // repeat center horizontally
        til.centerY = true;         // and vertically
        til.top     = true;         // repeat top strip horizontally
        til.bottom  = true;         // repeat bottom strip horizontally
        til.left    = true;         // repeat left strip vertically
        til.right   = true;         // repeat right strip vertically
        // til.background = { 24, 24, 24, 255 };   // optional solid bg
        til.pixelScale = 1.0f;      // usually your UI pixel scale (1/2/3...), keep integer for crisp pixels

        
        auto progressBar9Patch = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(GRAY)
                    // .addEmboss(2.f)
                    .addMinHeight(50.f)
                    .addMinWidth(500.f)
                    .addStylingType(ui::UIStylingType::NINEPATCH_BORDERS)
                    .addNPatchInfo(exampleNine->info)
                    .addNPatchTiling(til)
                    .addNPatchSourceTexture(exampleNine->texture)
                    .addProgressBar(true)
                    .addProgressBarEmptyColor(YELLOW)
                    .addProgressBarFullColor(PINK)
                    .addProgressBarFetchValueLamnda([](entt::entity e)
                                    { 
                                        return progressValueExample9Patch;
                                    })
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(progressBarTextMoving)
            .build();

        return progressBar9Patch;
    }

    inline auto getButtonDisabledExample() -> ui::UIElementTemplateNode
    {
        auto buttonDynamicText = getNewDynamicTextEntry(localization::get("ui.disabled_button"), 20.f, std::nullopt, "pulse=0.9,1.1");
        buttonDynamicText.config.initFunc = [](entt::registry* registry, entt::entity e) {
            localization::onLanguageChanged([&](auto newLang){
                TextSystem::Functions::setText(e, localization::get("ui.disabled_button"));
            });
        }; 
        
        auto buttonDisabled = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(RED)
                    .addId("buttonDisabled")
                    .addEmboss(2.f)
                    .addMinHeight(50.f)
                    .addMinWidth(300.f)
                    .addHover(true)
                    .addDisableButton(true) // disables clicking, darkens button
                    .addButtonCallback([]()
                                    { 
                                        SPDLOG_DEBUG("This should not be called");
                                    })
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(buttonDynamicText)
            .build();
            
        return buttonDisabled;
    }

    inline auto controllerPipContainer() -> ui::UIElementTemplateNode
    {
        auto controllerPipText = getNewDynamicTextEntry("Action", 10.f, std::nullopt, "pulse=0.9,1.1");
        auto anim = animation_system::createAnimatedObjectWithTransform("xbox_button_color_x.png", true, 0, 0);
        auto controllerPipImage = wrapEntityInsideObjectElement(anim);
        animation_system::resizeAnimationObjectsInEntityToFitAndCenterUI(anim, 30.f, 30.f);
        // disable shadow
        auto &gameObjectComp = globals::registry.get<transform::GameObject>(anim);
        gameObjectComp.shadowDisplacement.reset();
        
        auto controllerPipContainer = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(PINK)
                    .addEmboss(5.f)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(controllerPipText)
            .addChild(controllerPipImage)
            .build();
        
        return controllerPipContainer;
    }

    inline void moveInventoryItemToNewTile(entt::entity released, entt::entity releasedOn);

    inline auto uiFeaturesTestDef() -> ui::UIElementTemplateNode
    {
        auto masterVerticalContainer = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(YELLOW)
                    .addEmboss(2.f)
                    .addOutlineColor(BLUE)
                    // .addMaxWidth(300.f)
                    // .addMaxHeight(800.f)
                    // .addOutlineThickness(5.0f)
                    // .addMinWidth(500.f)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .build();
        
        auto titleDividers = ui_defs::putCodedTextBetweenDividers("UI Test", "divider-fade-001.png");
        
        // ======================================
        // ======================================
        // progress bar rounded rect
        // ======================================
        // ======================================
        auto progressBar = getProgressBarRoundedRectExample();
        
        // ======================================
        // ======================================
        // progress bar with ninepatch
        // ======================================
        // ======================================
            
        auto progressBar9Patch = getSliderNinepatchExample();

        // ======================================
        // ======================================
        // slider
        // ======================================
        // ======================================
        
        // auto sliderTextMoving = getNewDynamicTextEntry(localization::get("ui.slider_text"), 20.f, std::nullopt, "pulse=0.9,1.1");
        // sliderTextMoving.config.initFunc = [](entt::registry* registry, entt::entity e) {
        //     localization::onLanguageChanged([&](auto newLang){
        //         TextSystem::Functions::setText(e, localization::get("ui.slider_text"));
        //     });
        // }; 
        
        // auto slider = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addColor(GRAY)
        //             .addProgressBarMaxValue(100.f)
        //             // .addEmboss(2.f)
        //             .addMinHeight(50.f)
        //             .addNoMovementWhenDragged(true)
        //             .addMinWidth(500.f)
        //             .addProgressBar(true)
        //             .addProgressBarEmptyColor(WHITE)
        //             .addProgressBarFullColor(BLUE)
        //             .addInitFunc([](entt::registry* registry, entt::entity e)
        //             { 
        //                 SPDLOG_DEBUG("Slider init called for entity {}", (int)e);
        //                 auto &gameObject = globals::registry.get<transform::GameObject>(e);
        //                 gameObject.state.dragEnabled = true;
        //                 gameObject.state.collisionEnabled = true;
        //                 gameObject.state.clickEnabled = true;
        //                 gameObject.state.enlargeOnHover = false;
        //                 gameObject.state.enlargeOnDrag = false;
        //                 gameObject.methods.onHover = nullptr; // no jiggle
                        
        //                 // gameObject.state.hoverEnabled = true;
        //             })
        //             .addUpdateFunc([](entt::registry* registry, entt::entity e, float value)
        //             { 
        //                 // is mouse down? is the dragging darget the slider?
        //                 if (globals::inputState.cursor_dragging_target != e) return;
                        
        //                 // get mouse cursor position, compare to slider position
        //                 auto &sliderTransform = globals::registry.get<transform::Transform>(e);
        //                 auto &cursorTransform = globals::registry.get<transform::Transform>(globals::cursor);
                        
        //                 // clamp x value between 0 and slider width
        //                 auto sliderWidth = sliderTransform.getActualW();
        //                 auto sliderX = sliderTransform.getActualX();
                        
        //                 auto cursorX = cursorTransform.getActualX();
        //                 auto cursorY = cursorTransform.getActualY();
                        
        //                 auto clampedCursorX = std::clamp(cursorX, sliderX, sliderX + sliderWidth);
                        
        //                 // progress value is between 0 and 1
        //                 auto progressValue = (clampedCursorX - sliderX) / sliderWidth;
                        
        //                 // should be over 0.01
        //                 if (progressValue < 0.01f) progressValue = 0.01f;
                        
        //                 // set the progress value
        //                 auto &uiConfig = globals::registry.get<ui::UIConfig>(e);
                        
        //                 // SPDLOG_DEBUG("Slider value: {}", progressValue);
                        
        //                 uiConfig.progressBarFetchValueLambda = [progressValue](entt::entity e)
        //                 { 
        //                     return progressValue;
        //                 };
        //             })
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .addChild(sliderTextMoving)
        //     .build();
        // ======================================
        // ======================================
        // TODO: text input field
        // ======================================
        // ======================================
        
        // auto textInputTextMoving = getNewDynamicTextEntry(localization::get("ui.text_input"), 20.f, std::nullopt, "pulse=0.9,1.1");
        // textInputTextMoving.config.initFunc = [](entt::registry* registry, entt::entity e) {
        //     localization::onLanguageChanged([&](auto newLang){
        //         TextSystem::Functions::setText(e, localization::get("ui.text_input"));
        //     });
        // }; 
        // auto textInput = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addColor(WHITE)
        //             // .addEmboss(2.f)
        //             .addMinHeight(50.f)
        //             .addMinWidth(300.f)
        //             .addUpdateFunc([](entt::registry* registry, entt::entity e, float value)
        //                             { 
        //                                 // SPDLOG_DEBUG("Textinput update called");
        //                                 // allo this thing to be dragged, update based on mouse position
        //                             })
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .build();
        // auto textInputRow = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addColor(GRAY)
        //             // .addEmboss(2.f)
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .addChild(textInputTextMoving)
        //     .addChild(textInput)
        //     .build();
        
        // ======================================
        // ======================================
        // checkbox
        // ======================================
        // ======================================
        // auto checkbox = getCheckboxExample();
        
        // ======================================
        // ======================================
        // disabled button
        // ======================================
        // ======================================
        
        // auto buttonDisabled = getButtonDisabledExample();
        
        // ======================================
        // ======================================
        //button group
        // ======================================
        // ======================================
        // auto buttonGroupRow = getButtonGroupRowDef();
        
        // ======================================
        // ======================================
        // TODO: cycle (how to do pips?)
        // ======================================
        // ======================================
        // auto cycleText = getNewTextEntry(localization::get("ui.cycle_text"));
        // cycleText.config.initFunc = [](entt::registry* registry, entt::entity e) {
        //     localization::onLanguageChanged([&](auto newLang){
        //         TextSystem::Functions::setText(e, localization::get("ui.cycle_text"));
        //     });
        // }; 
        // auto cycleImageLeft = animation_system::createAnimatedObjectWithTransform("left.png", true, 0, 0, nullptr, false); // no shadow
        // auto cycleImageRight = animation_system::createAnimatedObjectWithTransform("right.png", true, 0, 0, nullptr, false); // no shadow
        // animation_system::resizeAnimationObjectsInEntityToFit(cycleImageLeft, 40.f, 40.f);
        // animation_system::resizeAnimationObjectsInEntityToFit(cycleImageRight, 40.f, 40.f);
        // auto cycleImageLeftUI = wrapEntityInsideObjectElement(cycleImageLeft);
        // auto cycleImageRightUI = wrapEntityInsideObjectElement(cycleImageRight);
        // auto leftButton = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addColor(RED)
        //             .addEmboss(2.f)
        //             .addMaxHeight(50.f)
        //             .addMaxWidth(50.f)
        //             .addHover(true)
        //             .addButtonCallback([]()
        //                             { SPDLOG_DEBUG("Left button callback triggered"); })
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .addChild(cycleImageLeftUI)
        //     .build();
        // auto rightButton = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addColor(RED)
        //             .addEmboss(2.f)
        //             .addMaxHeight(50.f)
        //             .addMaxWidth(50.f)
        //             .addHover(true)
        //             .addButtonCallback([]()
        //                             { SPDLOG_DEBUG("Right button callback triggered"); })
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .addChild(cycleImageRightUI)
        //     .build();
        // auto centerText = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addColor(PINK)
        //             .addEmboss(2.f)
        //             .addMaxHeight(50.f)
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .addChild(cycleText)
        //     .build();
        // auto cycleContainer = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addColor(GRAY)
        //             .addEmboss(2.f)
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .addChild(leftButton)
        //     .addChild(centerText)
        //     .addChild(rightButton)
        //     .build();
            
        // ======================================
        // ======================================
        // TODO: alert 
        // ======================================
        // ======================================
        // static entt::entity alertBox{entt::null};
        // auto alertText = getNewDynamicTextEntry("!", 20.f, std::nullopt, "wiggle");
        // // auto alertText = getNewTextEntry("Alert");
        
        // auto alertRow = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             // .addPadding(2.f)
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_LEFT | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .addChild(alertText)
        //     .build();
        
        // auto alertRoot = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::ROOT)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addPadding(0.f)
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .addChild(alertRow)
        //     .build();
            
        // alertBox = ui::box::Initialize(globals::registry, {.x = 500, .y = 700}, alertRoot, ui::UIConfig{});
        
        // SPDLOG_DEBUG("{}", ui::box::DebugPrint(globals::registry, alertBox, 0));
        
        // ======================================
        // ======================================
        // TODO: onscreen keyboard
        // ======================================
        // ======================================
        
        // entt::entity keyboardUIBox{entt::null};
        
        // auto numbers = std::vector<std::string>{"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"};
        // auto letterRow1 = std::vector<std::string>{"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"};
        // auto letterRow2 = std::vector<std::string>{"A", "S", "D", "F", "G", "H", "J", "K", "L"};
        // auto letterRow3 = std::vector<std::string>{"Z", "X", "C", "V", "B", "N", "M"};
        // auto essentialKeys = std::vector<std::string>{"Enter", "Clear"};
        
        // std::vector<ui::UIElementTemplateNode> keyboardRows;
        
        // auto makeKeyboardKey = [](const std::string &keyText, const std::function<void()>& callback) -> ui::UIElementTemplateNode {
        //     auto keyTextEntry = getNewDynamicTextEntry(keyText, 15.f, std::nullopt, "pulse=0.9,1.1");
        //     return ui::UIElementTemplateNode::Builder::create()
        //         .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        //         .addConfig(
        //             ui::UIConfig::Builder::create()
        //                 .addColor(GRAY)
        //                 .addEmboss(2.f)
        //                 .addMinHeight(30.f)
        //                 .addMinWidth(30.f)
        //                 .addHover(true)
        //                 .addButtonCallback(callback)
        //                 .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //                 .build())
        //         .addChild(keyTextEntry)
        //         .build();
        // };
        
        // // Create number row
        // auto numberRow = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addColor(BLANK)
        //             .addEmboss(2.f)
        //             .addPadding(1.f)
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build());
                    
        // for (const auto &num : numbers) {
        //     numberRow.addChild(makeKeyboardKey(num, [num]()
        //                             { 
        //                                 SPDLOG_DEBUG("Number key {} pressed", num);
        //                             }));
        // }
        // keyboardRows.push_back(numberRow.build());
        
        // // Create letter rows
        
        // auto makeLetterRow = [&](const std::vector<std::string> &letters) -> ui::UIElementTemplateNode {
        //     auto letterRow = ui::UIElementTemplateNode::Builder::create()
        //         .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        //         .addConfig(
        //             ui::UIConfig::Builder::create()
        //                 .addColor(BLANK)
        //                 .addPadding(1.f)
        //                 .addEmboss(2.f)
        //                 .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //                 .build());
                        
        //     for (const auto &letter : letters) {
        //         letterRow.addChild(makeKeyboardKey(letter, [letter]()
        //                             { 
        //                                 SPDLOG_DEBUG("Letter key {} pressed", letter);
        //                             }));
        //     }
        //     return letterRow.build();
        // };
        // keyboardRows.push_back(makeLetterRow(letterRow1));
        // keyboardRows.push_back(makeLetterRow(letterRow2));
        // keyboardRows.push_back(makeLetterRow(letterRow3));
        
        // // Create essential keys row
        // auto essentialRow = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addColor(BLANK)
        //             .addEmboss(2.f)
        //             .addPadding(1.f)
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build());
        // for (const auto &key : essentialKeys) {
        //     essentialRow.addChild(makeKeyboardKey(key, [key]()
        //                             { 
        //                                 SPDLOG_DEBUG("Essential key {} pressed", key);
        //                             }));
        // }
        // keyboardRows.push_back(essentialRow.build());
        // // Create the keyboard container
        // auto keyboardContainer = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addColor(WHITE)
        //             .addEmboss(2.f)
        //             .addPadding(0.f)
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build());
        // for (const auto &row : keyboardRows) {
        //     keyboardContainer.addChild(row);
        // }
        
        // auto keyboardRoot = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::ROOT)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .addChild(keyboardContainer.build())
        //     .build();
            
        // keyboardUIBox = ui::box::Initialize(globals::registry, {.x = 100, .y = 200}, keyboardRoot, ui::UIConfig{});

        // ======================================
        // ======================================
        // TODO: new row with an alert on the top right corner
        // ======================================
        // ======================================
        // auto buttonAlertText = getNewDynamicTextEntry(localization::get("ui.alert_button_text"), 20.f, std::nullopt, "wave");
        // buttonAlertText.config.initFunc = [](entt::registry* registry, entt::entity e) {
        //     localization::onLanguageChanged([&](auto newLang){
        //         TextSystem::Functions::setText(e, localization::get("ui.alert_button_text"));
        //     });
        // };
        // auto buttonAlert = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addColor(WHITE)
        //             .addEmboss(2.f)
        //             .addMinHeight(50.f)
        //             .addMinWidth(300.f)
        //             .addHover(true)
        //             .addButtonCallback([]()
        //                             { SPDLOG_DEBUG("Button callback triggered"); })
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .addChild(buttonAlertText)
        //     .build();
        
        // ======================================
        // ======================================
        // controller button pip
        // ======================================
        // ======================================
        // auto controllerPipContainer = ui_defs::controllerPipContainer();
        
        // ======================================
        // ======================================
        // TODO: tooltip
        // ======================================
        // ======================================
        
        // static entt::entity tooltipBox{entt::null};
        
        // //TODO: use backgrounds & images for the tooltip text
        // auto tooltipTitle = getNewDynamicTextEntry(localization::get("ui.tooltip_title"), 20.f, std::nullopt, "pulse=0.9,1.1");
        // tooltipTitle.config.initFunc = [](entt::registry* registry, entt::entity e) {
        //     localization::onLanguageChanged([&](auto newLang){
        //         TextSystem::Functions::setText(e, localization::get("ui.tooltip_title"));
        //     });
        // };
        
        // auto tooltipText = getNewDynamicTextEntry(localization::get("ui.tooltip_text", fmt::arg("text_type", "dynamic")), 10.f, std::nullopt, "pulse=0.9,1.1");
        // tooltipText.config.initFunc = [](entt::registry* registry, entt::entity e) {
        //     localization::onLanguageChanged([&](auto newLang){
        //         TextSystem::Functions::setText(e, localization::get("ui.tooltip_text", fmt::arg("text_type", "dynamic")));
        //     });
        // };
        
        // auto tooltipRow = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addOutlineColor(RED)
        //             .addOutlineThickness(4.f)
        //             .addEmboss(2.f)
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .addChild(tooltipTitle)
        //     .addChild(tooltipText)
        //     .build();
            
        // auto tooltipRoot = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::ROOT)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .addChild(tooltipRow)
        //     .build();
            
        // tooltipBox = ui::box::Initialize(globals::registry, {.x = 500, .y = 500}, tooltipRoot);

        // ======================================
        // ======================================
        // TODO: a button with a tooltip
        // ======================================
        // ======================================
        // auto tooltipButtonText = getNewDynamicTextEntry(localization::get("ui.tooltip_text_hover"), 20.f, std::nullopt, "rainbow");
        // tooltipButtonText.config.initFunc = [](entt::registry* registry, entt::entity e) {
        //     localization::onLanguageChanged([&](auto newLang){
        //         TextSystem::Functions::setText(e, localization::get("ui.tooltip_text_hover"));
        //     });
        // };
        // auto buttonForTooltip = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addColor(GRAY)
        //             .addEmboss(2.f)
        //             .addMinHeight(50.f)
        //             .addMinWidth(300.f)
        //             .addHover(true)
        //             .addButtonCallback([]()
        //                             { SPDLOG_DEBUG("Button callback triggered"); 
                                        
        //                             })
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .addChild(tooltipButtonText)
        //     .build();
            
        // ======================================
        // ======================================
        // TODO: Highlight ui box / doesn't need to be used rn, since we aren't doing controller at the moment
        // ======================================
        // ======================================
        // static entt::entity highlightBox{entt::null};
        
        // auto highlightRoot = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::ROOT)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addColor(BLANK)
        //             .addOutlineColor(RED)
        //             .addOutlineThickness(4.f)
        //             .addEmboss(2.f)
        //             .addLineEmboss(true)
        //             .addMinHeight(60.f)
        //             .addMinWidth(60.f)
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .build();
        // // highlightBox = ui::box::Initialize(globals::registry, {.x = 500, .y = 500}, highlightRoot);
        
        // ======================================
        // ======================================
        // TODO: object grid with selector rect outline which hovers over the selected object
        // ======================================
        // ======================================

        // int gridWidth = 5;
        // int gridHeight = 3;
    
        // auto gridRect = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::RECT_SHAPE)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addColor(WHITE)
        //             .addEmboss(2.f)
        //             .addMinWidth(60.f)
        //             .addMinHeight(60.f)
        //             .addOnUIScalingResetToOne(
        //                 [](entt::registry* registry, entt::entity e)
        //                 {
        //                     // set the size of the grid rect to be 60 x 60
                            
        //                     auto &transform = globals::registry.get<transform::Transform>(e);
        //                     transform.setActualW(60.f);
        //                     transform.setActualH(60.f);
                            
        //                     auto &role = globals::registry.get<transform::InheritedProperties>(e);
        //                     role.offset->x = 0;
        //                     role.offset->y = 0;
                            
        //                 })
        //             .addOnUIResizeFunc([](entt::registry* registry, entt::entity e)
        //             {
        //                 // renew centering 
        //                 auto &inventoryTile = globals::registry.get<ui::InventoryGridTileComponent>(e);
                        
        //                 if (!inventoryTile.item) return;
                        
        //                 SPDLOG_DEBUG("Grid rect resize called for entity: {} with item: {}", (int)e, (int)inventoryTile.item.value());
                        
        //                 game::centerInventoryItemOnTargetUI(inventoryTile.item.value(), e);
        //             })
        //             .addInitFunc([](entt::registry* registry, entt::entity e)
        //             { 
        //                 if (!globals::registry.any_of<ui::InventoryGridTileComponent>(e)) {
        //                     globals::registry.emplace<ui::InventoryGridTileComponent>(e);   
        //                 }
                        
        //                 auto &inventoryTile = globals::registry.get<ui::InventoryGridTileComponent>(e);
                        
        //                 auto &gameObjectComp = globals::registry.get<transform::GameObject>(e);
        //                 gameObjectComp.state.triggerOnReleaseEnabled = true;
        //                 gameObjectComp.state.collisionEnabled = true;
        //                 // gameObjectComp.state.hoverEnabled = true;
        //                 SPDLOG_DEBUG("Grid rect init called for entity: {}", (int)e);
                        
                        
        //                 gameObjectComp.methods.onRelease = [](entt::registry &registry, entt::entity releasedOn, entt::entity released)
        //                 {
        //                     SPDLOG_DEBUG("Grid rect onRelease called for entity {} released on top of entity {}", (int)released, (int)releasedOn);
                            
        //                     auto &inventoryTileReleasedOn = registry.get<ui::InventoryGridTileComponent>(releasedOn);
                            
                            
                            
        //                     // set master role for the released entity
        //                     auto &uiConfigOnReleased = registry.get<ui::UIConfig>(releasedOn);
        //                     auto &roleReleased = registry.get<transform::InheritedProperties>(released);
                            
        //                     // get previous parent (if any)
        //                     auto prevParent = roleReleased.master;
                            
                            
        //                     if (globals::registry.valid(prevParent))
        //                     {
        //                         auto &uiConfig = globals::registry.get<ui::UIConfig>(prevParent);
        //                         uiConfig.color = globals::uiInventoryEmpty;
                                
        //                         auto &prevInventoryTile = globals::registry.get<ui::InventoryGridTileComponent>(prevParent);
                                
        //                         // if current tile is occupied, then switch the items
        //                         //TODO: handle cases where something already exists in the inventory tile
        //                         if (inventoryTileReleasedOn.item)
        //                         {
        //                             SPDLOG_DEBUG("Inventory tile already occupied, switching");
                                    
        //                             auto temp = inventoryTileReleasedOn.item.value();
        //                             inventoryTileReleasedOn.item = released;
        //                             prevInventoryTile.item = temp;
                                    
        //                             //TODO: apply the centering & master role switching
        //                             moveInventoryItemToNewTile(released, releasedOn);
        //                             moveInventoryItemToNewTile(temp, prevParent);
        //                             return;
        //                         }
        //                         else {
        //                             inventoryTileReleasedOn.item = released;
        //                             prevInventoryTile.item.reset();
        //                         }
                                
        //                     }

        //                     moveInventoryItemToNewTile(released, releasedOn);
                            
                            
        //                 };
                        
        //             })
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .build();
        // auto gridRow = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .build();
        // for (int i = 0; i < gridWidth; i++) {
        //     gridRow.children.push_back(gridRect);
        // }
        // auto gridContainer = ui::UIElementTemplateNode::Builder::create()
        //     .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
        //     .addConfig(
        //         ui::UIConfig::Builder::create()
        //             .addColor(GRAY)
        //             .addPadding(2.f)
        //             .addEmboss(2.f)
        //             .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
        //             .build())
        //     .build();
        // for (int i = 0; i < gridHeight; i++) {
        //     gridContainer.children.push_back(gridRow);
        // }
        
        
        // add everything to the master vertical container
        masterVerticalContainer.children.push_back(titleDividers);
        // masterVerticalContainer.children.push_back(checkbox);
        // masterVerticalContainer.children.push_back(progressBar);
        masterVerticalContainer.children.push_back(progressBar9Patch);
        // masterVerticalContainer.children.push_back(buttonDisabled);
        // masterVerticalContainer.children.push_back(controllerPipContainer);
        // masterVerticalContainer.children.push_back(slider);
        // masterVerticalContainer.children.push_back(textInputRow);
        // masterVerticalContainer.children.push_back(buttonGroupRow);
        // masterVerticalContainer.children.push_back(cycleContainer);
        // masterVerticalContainer.children.push_back(gridContainer);
        // masterVerticalContainer.children.push_back(buttonForTooltip);
        // masterVerticalContainer.children.push_back(buttonAlert);

        
        return masterVerticalContainer;
    }
    
    
    inline void exposeToLua(sol::state &lua)
    {
        sol::table ui    = lua["ui"].get_or_create<sol::table>();
        sol::table elem  = ui.create_named("definitions");
        
        auto &rec = BindingRecorder::instance();

        // 1) InputState usertype
        rec.add_type("ui.definitions");
        
        // 1) getNewTextEntry(text[, refEntity[, refComponent[, refValue]]])
        elem.set_function("getNewTextEntry", sol::overload(
            [](const std::string& text) {
                return getNewTextEntry(text);
            },
            [](const std::string& text, entt::entity refEntity) {
                return getNewTextEntry(text, refEntity);
            },
            [](const std::string& text, entt::entity refEntity, const std::string& refComponent) {
                return getNewTextEntry(text, refEntity, refComponent);
            },
            [](const std::string& text, entt::entity refEntity, const std::string& refComponent, const std::string& refValue) {
                return getNewTextEntry(text, refEntity, refComponent, refValue);
            }
        ));
        rec.record_free_function(
            {"ui","definitions"},
            {"getNewTextEntry", R"(
        ---@overload fun(text:string):UIElementTemplateNode
        ---@overload fun(text:string, refEntity:Entity):UIElementTemplateNode
        ---@overload fun(text:string, refEntity:Entity, refComponent:string):UIElementTemplateNode
        ---@param text string
        ---@param refEntity? Entity
        ---@param refComponent? string
        ---@param refValue? string
        ---@return UIElementTemplateNode
        )", 
            "Create a static text‐entry node, with optional entity/component/value refs.", 
            true, false}
        );
        
        // clone whatever function is passed in to the main Lua state, so we won't have issues with lua threads going out of scope (if timers are called from a coroutine)
        auto clone_to_main = [](sol::function thread_fn) {
            // 1) get a view of your real, main-state Lua
            sol::state_view main_sv{ ai_system::masterStateLua };
        
            // 2) stash the passed-in function into a temporary global
            main_sv.set("__timer_import", thread_fn);
        
            // 3) pull it back out — now it’s bound to the main-state lua_State*
            sol::function main_fn = main_sv.get<sol::function>("__timer_import");
        
            // 4) clean up the temp
            main_sv["__timer_import"] = sol::lua_nil;
        
            return main_fn;
        };

        // 2) getNewDynamicTextEntry(text, fontSize[, wrapWidth[, textEffect[, refEntity[, refComponent[, refValue]]]]])
        elem.set_function("getNewDynamicTextEntry", 
            // use a single lambda with sol::optional to let Lua omit any trailing args
            [clone_to_main](sol::function localizedStringGetter,
            float fontSize,
            sol::optional<std::string> textEffect,
            sol::optional<bool> updateOnLanguageChange,
            sol::optional<float>      wrapWidth,
            sol::optional<entt::entity> refEntity,
            sol::optional<std::string>  refComponent,
            sol::optional<std::string>  refValue
        )
            {
                // assert localizedStringGetter.valid()
                if (!localizedStringGetter.valid()) {
                    SPDLOG_ERROR("getNewDynamicTextEntry called without a valid localizedStringGetter function");
                    throw std::runtime_error("getNewDynamicTextEntry requires a valid localizedStringGetter function");
                }
                
                auto text = localizedStringGetter.call<std::string>("ERROR: default"); // default text if no localized string is provided
                
                auto entity = getNewDynamicTextEntry(
                    text,
                    fontSize,
                    wrapWidth ? std::make_optional(*wrapWidth) : std::nullopt,
                    textEffect ? std::make_optional(*textEffect) : std::nullopt,
                    refEntity ? std::make_optional(*refEntity) : std::nullopt,
                    refComponent ? std::make_optional(*refComponent) : std::nullopt,
                    refValue ? std::make_optional(*refValue) : std::nullopt
                );
                
                // set it as the init function so that automatically updates the text when the language changes
                // default to true for updateOnLanguageChange if not provided
                if ((!updateOnLanguageChange) || (updateOnLanguageChange && *updateOnLanguageChange)) {
                    // Register a callback to update the text when the language changes
                    entity.config.initFunc = [getter = clone_to_main(localizedStringGetter)](entt::registry* registry, entt::entity e) {
                        localization::onLanguageChanged([getter, e](const std::string& newLang) {
                            // get the object inside the config component
                            auto &config = globals::registry.get<ui::UIConfig>(e);
                            auto textEntity = config.object.value();
                            
                            // Call the Lua function to get the localized text
                            auto localizedText = getter.call<std::string>(newLang);
                            // Set the text in the TextSystem
                            TextSystem::Functions::setText(textEntity, localizedText);
                        });
                    };
                }
                
                return entity;
            }
        );
        rec.record_free_function(
            {"ui","definitions"},
            {"getNewDynamicTextEntry", R"(
        ---@param localizedStringGetter fun(langCode:string):string
        ---@param fontSize number
        ---@param textEffect? string
        ---@param updateOnLanguageChange? boolean, defaults to true
        ---@param wrapWidth? number
        ---@param refEntity? Entity
        ---@param refComponent? string
        ---@param refValue? string
        ---@return UIElementTemplateNode
        )",
            "Create a text‐entry node with dynamic effects (wrapping, pulse, etc.) and optional refs.",
            true, false}
        );

        // 3) getTextFromString(text)
        elem.set_function("getTextFromString", &getTextFromString);
        rec.record_free_function(
            {"ui","definitions"},
            {"getTextFromString", "---@param text string\n---@return UIElementTemplateNode", 
            "Wrap a raw string into a UI text node.", 
            true, false}
        );

        // 4) putCodedTextBetweenDividers(text, divider)
        elem.set_function("putCodedTextBetweenDividers", &putCodedTextBetweenDividers);
        rec.record_free_function(
            {"ui","definitions"},
            {"putCodedTextBetweenDividers", "---@param text string\n---@param divider string\n---@return UIElementTemplateNode", 
            "Embed text between divider markers (for code‐style blocks).", 
            true, false}
        );

        // 5) wrapEntityInsideObjectElement(entity)
        elem.set_function("wrapEntityInsideObjectElement", &wrapEntityInsideObjectElement);
        rec.record_free_function(
            {"ui","definitions"},
            {"wrapEntityInsideObjectElement", "---@param entity Entity\n---@return UIElementTemplateNode", 
            "Turn an existing entity into a UI object‐element node.", 
            true, false}
        );
    }
}