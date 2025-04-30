#pragma once

#include <tuple>

#include "core/globals.hpp"
#include "util/common_headers.hpp"
#include "util/utilities.hpp"
#include "systems/text/textVer2.hpp"
#include "systems/text/static_ui_text.hpp"

#include "systems/ui/ui.hpp"


namespace ui_defs
{
    // randomly sized rectangle (rounded)
    inline auto getRandomRectDef() -> ui::UIElementTemplateNode
    {
        NPatchInfo nPatchinfo;
        Texture2D npatchTexture;
        std::tie(nPatchinfo, npatchTexture) = animation_system::getNinepatchUIBorderInfo("panel-005.png");
        
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
        std::tie(nPatchinfo, npatchTexture) = animation_system::getNinepatchUIBorderInfo("panel-005.png");

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

            for (auto j = 0; j < segments; j++) {
                auto segment = row.segments[j];


                auto textSegmentDef = getNewTextEntry(segment.text);

                if (segment.attributes.find("color") != segment.attributes.end()) {
                    auto colorString = std::get<std::string>(segment.attributes["color"]);

                    auto color = util::getColor(colorString);

                    textSegmentDef.config.color = color;
                }
                if (segment.attributes.find("background") != segment.attributes.end()) {
                    auto backgroundString = std::get<std::string>(segment.attributes["background"]);

                    auto color = util::getColor(backgroundString);

                    // wrap in a horizontal container
                    auto wrapperDef = ui::UIElementTemplateNode::Builder::create()
                        .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
                        .addConfig(
                            ui::UIConfig::Builder::create()
                                .addColor(color)
                                .addPadding(4.f)
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
                    .addMinWidth(100.f)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build());
        
        for (auto &rowDef : textRowDefs) {
            textDef.addChild(rowDef);
        }

        return textDef.build();
    }
}