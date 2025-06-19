
-- build defs here


local ui_defs = {}

local currencyBox = {}
function ui_defs.getCurrencyInfoBox()
    -- shows the list of currencies and their amounts
    
    -- image + name + amount, amount accessed via lambda
    -- non-unlocked ones are greyed out
end


function ui_defs.getShowPurchasedBuildingBox()
    -- shows the purchased building (only one slot)
    
    
    
    -- just a inventory square slot with text above it that says "Purchased"

    -- int gridWidth = 5;
    --     int gridHeight = 3;
    
    --     auto gridRect = ui::UIElementTemplateNode::Builder::create()
    --         .addType(ui::UITypeEnum::RECT_SHAPE)
    --         .addConfig(
    --             ui::UIConfig::Builder::create()
    --                 .addColor(WHITE)
    --                 .addEmboss(2.f)
    --                 .addMinWidth(60.f)
    --                 .addMinHeight(60.f)
    --                 .addOnUIScalingResetToOne(
    --                     [](entt::registry* registry, entt::entity e)
    --                     {
    --                         // set the size of the grid rect to be 60 x 60
                            
    --                         auto &transform = globals::registry.get<transform::Transform>(e);
    --                         transform.setActualW(60.f);
    --                         transform.setActualH(60.f);
                            
    --                         auto &role = globals::registry.get<transform::InheritedProperties>(e);
    --                         role.offset->x = 0;
    --                         role.offset->y = 0;
                            
    --                     })
    --                 .addOnUIResizeFunc([](entt::registry* registry, entt::entity e)
    --                 {
    --                     // renew centering 
    --                     auto &inventoryTile = globals::registry.get<ui::InventoryGridTileComponent>(e);
                        
    --                     if (!inventoryTile.item) return;
                        
    --                     SPDLOG_DEBUG("Grid rect resize called for entity: {} with item: {}", (int)e, (int)inventoryTile.item.value());
                        
    --                     game::centerInventoryItemOnTargetUI(inventoryTile.item.value(), e);
    --                 })
    --                 .addInitFunc([](entt::registry* registry, entt::entity e)
    --                 { 
    --                     if (!globals::registry.any_of<ui::InventoryGridTileComponent>(e)) {
    --                         globals::registry.emplace<ui::InventoryGridTileComponent>(e);   
    --                     }
                        
    --                     auto &inventoryTile = globals::registry.get<ui::InventoryGridTileComponent>(e);
                        
    --                     auto &gameObjectComp = globals::registry.get<transform::GameObject>(e);
    --                     gameObjectComp.state.triggerOnReleaseEnabled = true;
    --                     gameObjectComp.state.collisionEnabled = true;
    --                     // gameObjectComp.state.hoverEnabled = true;
    --                     SPDLOG_DEBUG("Grid rect init called for entity: {}", (int)e);
                        
                        
    --                     gameObjectComp.methods.onRelease = [](entt::registry &registry, entt::entity releasedOn, entt::entity released)
    --                     {
    --                         SPDLOG_DEBUG("Grid rect onRelease called for entity {} released on top of entity {}", (int)released, (int)releasedOn);
                            
    --                         auto &inventoryTileReleasedOn = registry.get<ui::InventoryGridTileComponent>(releasedOn);
                            
                            
                            
    --                         // set master role for the released entity
    --                         auto &uiConfigOnReleased = registry.get<ui::UIConfig>(releasedOn);
    --                         auto &roleReleased = registry.get<transform::InheritedProperties>(released);
                            
    --                         // get previous parent (if any)
    --                         auto prevParent = roleReleased.master;
                            
                            
    --                         if (globals::registry.valid(prevParent))
    --                         {
    --                             auto &uiConfig = globals::registry.get<ui::UIConfig>(prevParent);
    --                             uiConfig.color = globals::uiInventoryEmpty;
                                
    --                             auto &prevInventoryTile = globals::registry.get<ui::InventoryGridTileComponent>(prevParent);
                                
    --                             // if current tile is occupied, then switch the items
    --                             //TODO: handle cases where something already exists in the inventory tile
    --                             if (inventoryTileReleasedOn.item)
    --                             {
    --                                 SPDLOG_DEBUG("Inventory tile already occupied, switching");
                                    
    --                                 auto temp = inventoryTileReleasedOn.item.value();
    --                                 inventoryTileReleasedOn.item = released;
    --                                 prevInventoryTile.item = temp;
                                    
    --                                 //TODO: apply the centering & master role switching
    --                                 moveInventoryItemToNewTile(released, releasedOn);
    --                                 moveInventoryItemToNewTile(temp, prevParent);
    --                                 return;
    --                             }
    --                             else {
    --                                 inventoryTileReleasedOn.item = released;
    --                                 prevInventoryTile.item.reset();
    --                             }
                                
    --                         }

    --                         moveInventoryItemToNewTile(released, releasedOn);
                            
                            
    --                     };
                        
    --                 })
    --                 .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
    --                 .build())
    --         .build();
    --     auto gridRow = ui::UIElementTemplateNode::Builder::create()
    --         .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
    --         .addConfig(
    --             ui::UIConfig::Builder::create()
    --                 .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
    --                 .build())
    --         .build();
    --     for (int i = 0; i < gridWidth; i++) {
    --         gridRow.children.push_back(gridRect);
    --     }
    --     auto gridContainer = ui::UIElementTemplateNode::Builder::create()
    --         .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
    --         .addConfig(
    --             ui::UIConfig::Builder::create()
    --                 .addColor(GRAY)
    --                 .addPadding(2.f)
    --                 .addEmboss(2.f)
    --                 .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
    --                 .build())
    --         .build();
    --     for (int i = 0; i < gridHeight; i++) {
    --         gridContainer.children.push_back(gridRow);
    --     }
        
end

function ui_defs.getPossibleUpgradesBox()
    -- shows the possible upgrades purchasable (cycle)
    
    -- A small cycle thing which shows an image of the upgrade at the center. Hover to see more info.
    
    -- auto cycleText = getNewTextEntry(localization::get("ui.cycle_text"));
    --     cycleText.config.initFunc = [](entt::registry* registry, entt::entity e) {
    --         localization::onLanguageChanged([&](auto newLang){
    --             TextSystem::Functions::setText(e, localization::get("ui.cycle_text"));
    --         });
    --     }; 
    --     auto cycleImageLeft = animation_system::createAnimatedObjectWithTransform("left.png", true, 0, 0, nullptr, false); // no shadow
    --     auto cycleImageRight = animation_system::createAnimatedObjectWithTransform("right.png", true, 0, 0, nullptr, false); // no shadow
    --     animation_system::resizeAnimationObjectsInEntityToFit(cycleImageLeft, 40.f, 40.f);
    --     animation_system::resizeAnimationObjectsInEntityToFit(cycleImageRight, 40.f, 40.f);
    --     auto cycleImageLeftUI = wrapEntityInsideObjectElement(cycleImageLeft);
    --     auto cycleImageRightUI = wrapEntityInsideObjectElement(cycleImageRight);
    --     auto leftButton = ui::UIElementTemplateNode::Builder::create()
    --         .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
    --         .addConfig(
    --             ui::UIConfig::Builder::create()
    --                 .addColor(RED)
    --                 .addEmboss(2.f)
    --                 .addMaxHeight(50.f)
    --                 .addMaxWidth(50.f)
    --                 .addHover(true)
    --                 .addButtonCallback([]()
    --                                 { SPDLOG_DEBUG("Left button callback triggered"); })
    --                 .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
    --                 .build())
    --         .addChild(cycleImageLeftUI)
    --         .build();
    --     auto rightButton = ui::UIElementTemplateNode::Builder::create()
    --         .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
    --         .addConfig(
    --             ui::UIConfig::Builder::create()
    --                 .addColor(RED)
    --                 .addEmboss(2.f)
    --                 .addMaxHeight(50.f)
    --                 .addMaxWidth(50.f)
    --                 .addHover(true)
    --                 .addButtonCallback([]()
    --                                 { SPDLOG_DEBUG("Right button callback triggered"); })
    --                 .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
    --                 .build())
    --         .addChild(cycleImageRightUI)
    --         .build();
    --     auto centerText = ui::UIElementTemplateNode::Builder::create()
    --         .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
    --         .addConfig(
    --             ui::UIConfig::Builder::create()
    --                 .addColor(PINK)
    --                 .addEmboss(2.f)
    --                 .addMaxHeight(50.f)
    --                 .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
    --                 .build())
    --         .addChild(cycleText)
    --         .build();
    --     auto cycleContainer = ui::UIElementTemplateNode::Builder::create()
    --         .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
    --         .addConfig(
    --             ui::UIConfig::Builder::create()
    --                 .addColor(GRAY)
    --                 .addEmboss(2.f)
    --                 .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
    --                 .build())
    --         .addChild(leftButton)
    --         .addChild(centerText)
    --         .addChild(rightButton)
    --         .build();
            
end

function ui_defs.createNewTooltipBox()
    -- generates a new tooltip box. Should be saved and reused on hover.
end

function ui_defs.makeTextAppearForTime(e)
    -- creates a text entity that appears for a certain amount of time, then vanishes.
end

function ui_defs.getSocialsBox()
    
end

function ui_defs.getMainMenuBox()
    
end

function ui_defs.getTooltipBox() 

    
end



return ui_defs