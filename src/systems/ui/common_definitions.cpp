#include "common_definitions.hpp"

#include "ui_data.hpp"
#include "core/ui_components.hpp"

namespace ui {

    // Implementation of UIConfig::Builder::buildBundle()
    UIConfigBundle UIConfig::Builder::buildBundle() const {
        UIConfigBundle bundle;
        bundle.style = extractStyle(uiConfig);
        bundle.layout = extractLayout(uiConfig);
        bundle.interaction = extractInteraction(uiConfig);
        bundle.content = extractContent(uiConfig);
        return bundle;
    }
    auto createTooltipUIBoxDef(entt::registry &registry, ui::Tooltip tooltip) -> ui::UIElementTemplateNode {

        ui::UIElementTemplateNode title = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::TEXT)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addText(tooltip.title.value_or("Tooltip Title"))
                    .addColor(BLACK)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .addFontName("tooltip")
                    // .addScale(0.4f)
                    .build())
            .build();
        ui::UIElementTemplateNode content = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::TEXT)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addText(tooltip.text.value_or("Tooltip Content"))
                    .addColor(RED)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .addFontName("tooltip")
                    // .addScale(0.4f)
                    .build())
            .build();

        ui::UIElementTemplateNode titleRow = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(GREEN)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(title)
            .build();

        ui::UIElementTemplateNode contentRow = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(WHITE)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(content)
            .build();


        ui::UIElementTemplateNode tooltipUIBoxDef = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::ROOT)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(WHITE)
                    .addOutlineThickness(2.0f)
                    .addOutlineColor(BLUE)
                    .build())
            .addChild(titleRow)
            .addChild(contentRow)
            .build();


        return tooltipUIBoxDef;
    }
}