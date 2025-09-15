

```cpp

    auto uiTest = ui_defs::uiFeaturesTestDef();
    
    auto testRoot = ui::UIElementTemplateNode::Builder::create()
        .addType(ui::UITypeEnum::ROOT)
        .addConfig(
            ui::UIConfig::Builder::create()
                .addPadding(0.f)
                .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                .build())
        .addChild(uiTest)
        .build();
        
    auto testBox = ui::box::Initialize(globals::registry, {.x = 800, .y = 600}, testRoot, ui::UIConfig{});
        
```