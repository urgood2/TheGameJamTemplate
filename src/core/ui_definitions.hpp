#pragma once

#include <tuple>

#include "core/globals.hpp"
#include "util/common_headers.hpp"
#include "util/utilities.hpp"
#include "systems/text/textVer2.hpp"
#include "systems/text/static_ui_text.hpp"
#include "systems/timer/timer.hpp"

#include "systems/ui/ui.hpp"


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
                        
                    textSegmentDefs.push_back(imageDef);
                    
                    continue;
                }


                auto textSegmentDef = getNewTextEntry(segment.text);

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
                    .addMaxHeight(50.f)
                    .addMaxWidth(50.f)
                    .addScale(0.5f)
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
        auto progressBar9Patch = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(GRAY)
                    // .addEmboss(2.f)
                    .addMinHeight(50.f)
                    .addMinWidth(500.f)
                    .addStylingType(ui::UIStylingType::NINEPATCH_BORDERS)
                    .addNPatchInfo(nPatchinfo)
                    .addNPatchSourceTexture(npatchTexture)
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
        auto buttonDynamicText = getNewDynamicTextEntry("Button (disabled)", 20.f, std::nullopt, "pulse=0.9,1.1");
        
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
        animation_system::resizeAnimationObjectsInEntityToFit(anim, 30.f, 30.f);
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
    
    inline auto uiFeaturesTestDef() -> ui::UIElementTemplateNode
    {
        auto masterVerticalContainer = ui::UIElementTemplateNode::Builder::create()
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
        // TODO: slider (not done yet)
        // ======================================
        // ======================================

        auto sliderTextMoving = getNewDynamicTextEntry("Slider (click or drag)", 20.f, std::nullopt, "pulse=0.9,1.1");
        auto slider = ui::UIElementTemplateNode::Builder::create()
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
                    .addUpdateFunc([](entt::registry* registry, entt::entity e, float value)
                                    { 
                                        SPDLOG_DEBUG("Slider update called");
                                        // allo this thing to be dragged, update based on mouse position
                                    })
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(sliderTextMoving)
            .build();
        // ======================================
        // ======================================
        // TODO: text input field
        // ======================================
        // ======================================
        
        auto textInputTextMoving = getNewDynamicTextEntry("Enter Name:", 20.f, std::nullopt, "pulse=0.9,1.1");
        auto textInput = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(WHITE)
                    // .addEmboss(2.f)
                    .addMinHeight(50.f)
                    .addMinWidth(300.f)
                    .addUpdateFunc([](entt::registry* registry, entt::entity e, float value)
                                    { 
                                        SPDLOG_DEBUG("Textinput update called");
                                        // allo this thing to be dragged, update based on mouse position
                                    })
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .build();
        auto textInputRow = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(GRAY)
                    // .addEmboss(2.f)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(textInputTextMoving)
            .addChild(textInput)
            .build();
        
        // ======================================
        // ======================================
        // checkbox
        // ======================================
        // ======================================
        auto checkbox = getCheckboxExample();
        
        // ======================================
        // ======================================
        // disabled button
        // ======================================
        // ======================================
        
        auto buttonDisabled = getButtonDisabledExample();
        
        // ======================================
        // ======================================
        //button group
        // ======================================
        // ======================================
        auto buttonGroupRow = getButtonGroupRowDef();
        
        // ======================================
        // ======================================
        // TODO: cycle (how to do pips?)
        // ======================================
        // ======================================
        auto cycleText = getNewTextEntry("Cycle");
        auto cycleImageLeft = animation_system::createAnimatedObjectWithTransform("left.png", true, 0, 0, nullptr, false); // no shadow
        auto cycleImageRight = animation_system::createAnimatedObjectWithTransform("right.png", true, 0, 0, nullptr, false); // no shadow
        animation_system::resizeAnimationObjectsInEntityToFit(cycleImageLeft, 40.f, 40.f);
        animation_system::resizeAnimationObjectsInEntityToFit(cycleImageRight, 40.f, 40.f);
        auto cycleImageLeftUI = wrapEntityInsideObjectElement(cycleImageLeft);
        auto cycleImageRightUI = wrapEntityInsideObjectElement(cycleImageRight);
        auto leftButton = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(RED)
                    .addEmboss(2.f)
                    .addMaxHeight(50.f)
                    .addMaxWidth(50.f)
                    .addHover(true)
                    .addButtonCallback([]()
                                    { SPDLOG_DEBUG("Left button callback triggered"); })
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(cycleImageLeftUI)
            .build();
        auto rightButton = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(RED)
                    .addEmboss(2.f)
                    .addMaxHeight(50.f)
                    .addMaxWidth(50.f)
                    .addHover(true)
                    .addButtonCallback([]()
                                    { SPDLOG_DEBUG("Right button callback triggered"); })
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(cycleImageRightUI)
            .build();
        auto centerText = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(PINK)
                    .addEmboss(2.f)
                    .addMaxHeight(50.f)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(cycleText)
            .build();
        auto cycleContainer = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(GRAY)
                    .addEmboss(2.f)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(leftButton)
            .addChild(centerText)
            .addChild(rightButton)
            .build();

        // ======================================
        // ======================================
        // TODO: new row with an alert on the top right corner
        // ======================================
        // ======================================
        auto buttonAlertText = getNewDynamicTextEntry("Alert on top right corner", 20.f, std::nullopt, "wave");
        auto buttonAlert = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(WHITE)
                    .addEmboss(2.f)
                    .addMinHeight(50.f)
                    .addMinWidth(300.f)
                    .addHover(true)
                    .addButtonCallback([]()
                                    { SPDLOG_DEBUG("Button callback triggered"); })
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(buttonAlertText)
            .build();
        
        // ======================================
        // ======================================
        // controller button pip
        // ======================================
        // ======================================
        auto controllerPipContainer = ui_defs::controllerPipContainer();

        // ======================================
        // ======================================
        // TODO: a button with a tooltip
        // ======================================
        // ======================================
        auto tooltipButtonText = getNewDynamicTextEntry("Hover for tooltip", 20.f, std::nullopt, "rainbow");
        auto buttonForTooltip = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(GRAY)
                    .addEmboss(2.f)
                    .addMinHeight(50.f)
                    .addMinWidth(300.f)
                    .addHover(true)
                    .addButtonCallback([]()
                                    { SPDLOG_DEBUG("Button callback triggered"); 
                                        
                                    })
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(tooltipButtonText)
            .build();
        
        // ======================================
        // ======================================
        // TODO: object grid with selector rect outline which hovers over the selected object
        // ======================================
        // ======================================

        int gridWidth = 5;
        int gridHeight = 3;
    
        auto gridRect = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::RECT_SHAPE)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(WHITE)
                    .addEmboss(2.f)
                    .addMinWidth(60.f)
                    .addMinHeight(60.f)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .build();
        auto gridRow = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .build();
        for (int i = 0; i < gridWidth; i++) {
            gridRow.children.push_back(gridRect);
        }
        auto gridContainer = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(GRAY)
                    .addPadding(2.f)
                    .addEmboss(2.f)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .build();
        for (int i = 0; i < gridHeight; i++) {
            gridContainer.children.push_back(gridRow);
        }
        
        
        // add everything to the master vertical container
        masterVerticalContainer.children.push_back(titleDividers);
        masterVerticalContainer.children.push_back(checkbox);
        masterVerticalContainer.children.push_back(progressBar);
        masterVerticalContainer.children.push_back(progressBar9Patch);
        masterVerticalContainer.children.push_back(buttonDisabled);
        masterVerticalContainer.children.push_back(controllerPipContainer);
        masterVerticalContainer.children.push_back(slider);
        masterVerticalContainer.children.push_back(textInputRow);
        masterVerticalContainer.children.push_back(buttonGroupRow);
        masterVerticalContainer.children.push_back(cycleContainer);
        masterVerticalContainer.children.push_back(gridContainer);
        masterVerticalContainer.children.push_back(buttonForTooltip);
        masterVerticalContainer.children.push_back(buttonAlert);
        
        return masterVerticalContainer;
    }
}