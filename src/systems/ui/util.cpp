#include "util.hpp"

#include "raymath.h"
#include "util/utilities.hpp"

namespace ui
{

    void util::RegisterMeta()
    {
        reflection::registerMetaForComponent<UIElementComponent>([](auto meta)
                                                                 {
            // .template data<&UIElementComponent::parent>("parent"_hs);
            meta.type("UIElementComponent"_hs)  // Ensure type name matches the lookup string
                .template data<&UIElementComponent::UIT>("UIT"_hs)
                .template data<&UIElementComponent::uiBox>("uiBox"_hs)
                .template data<&UIElementComponent::config>("config"_hs); });

        reflection::registerMetaForComponent<UIBoxComponent>([](auto meta)
                                                             { meta.type("UIBoxComponent"_hs) // Ensure type name matches the lookup string
                                                                   .template data<&UIBoxComponent::uiRoot>("uiRoot"_hs)
                                                                   .template data<&UIBoxComponent::drawLayers>("drawLayers"_hs); });

        reflection::registerMetaForComponent<UIState>([](auto meta)
                                                      { meta.type("UIState"_hs) // Ensure type name matches the
                                                            .template data<&UIState::contentDimensions>("contentDimensions"_hs)
                                                            .template data<&UIState::textDrawable>("textDrawable"_hs)
                                                            .template data<&UIState::last_clicked>("last_clicked"_hs)
                                                            .template data<&UIState::object_focus_timer>("object_focus_timer"_hs)
                                                            .template data<&UIState::focus_timer>("focus_timer"_hs); });

        reflection::registerMetaForComponent<Tooltip>([](auto meta)
                                                      { meta.type("Tooltip"_hs) // Ensure type name matches the lookup string
                                                            .template data<&Tooltip::title>("title"_hs)
                                                            .template data<&Tooltip::text>("text"_hs); });

        reflection::registerMetaForComponent<UIConfig>([](auto meta)
                                                       {
                                                           meta.type("UIConfig"_hs) // Ensure type name matches the lookup string
                                                               .template data<&UIConfig::id>("id"_hs)
                                                               .template data<&UIConfig::instanceType>("instanceType"_hs)
                                                               .template data<&UIConfig::uiType>("uiType"_hs)
                                                               .template data<&UIConfig::drawLayer>("drawLayer"_hs)
                                                               .template data<&UIConfig::group>("group"_hs)

                                                               .template data<&UIConfig::location_bond>("location_bond"_hs)
                                                               .template data<&UIConfig::rotation_bond>("rotation_bond"_hs)
                                                               .template data<&UIConfig::size_bond>("size_bond"_hs)
                                                               .template data<&UIConfig::scale_bond>("scale_bond"_hs)
                                                               .template data<&UIConfig::offset>("offset"_hs)
                                                               .template data<&UIConfig::scale>("scale"_hs)
                                                               .template data<&UIConfig::focusWithObject>("focusWithObject"_hs)
                                                               .template data<&UIConfig::refreshMovement>("refreshMovement"_hs)
                                                               .template data<&UIConfig::no_recalc>("no_recalc"_hs)
                                                               .template data<&UIConfig::non_recalc>("non_recalc"_hs)

                                                               .template data<&UIConfig::parent>("parent"_hs)
                                                               // .template data<&UIConfig::nodes>("nodes"_hs)
                                                               .template data<&UIConfig::object>("object"_hs)

                                                               .template data<&UIConfig::alignmentFlags>("align"_hs)
                                                               .template data<&UIConfig::width>("width"_hs)
                                                               .template data<&UIConfig::height>("height"_hs)
                                                               .template data<&UIConfig::maxWidth>("max_width"_hs)
                                                               .template data<&UIConfig::maxHeight>("max_height"_hs)
                                                               .template data<&UIConfig::minWidth>("min_width"_hs)
                                                               .template data<&UIConfig::minHeight>("min_height"_hs)
                                                               .template data<&UIConfig::padding>("padding"_hs)

                                                               .template data<&UIConfig::color>("colour"_hs)
                                                               .template data<&UIConfig::outlineColor>("outlineColour"_hs)
                                                               .template data<&UIConfig::outlineThickness>("outline"_hs)
                                                               .template data<&UIConfig::shadow>("shadow"_hs)
                                                               .template data<&UIConfig::shadowColor>("shadowColour"_hs)
                                                               .template data<&UIConfig::noFill>("noFill"_hs)
                                                               .template data<&UIConfig::pixelatedRectangle>("pixelatedRectangle"_hs)

                                                               .template data<&UIConfig::canCollide>("canCollide"_hs)
                                                               .template data<&UIConfig::collideable>("collideable"_hs)
                                                               .template data<&UIConfig::forceCollision>("forceCollision"_hs)
                                                               .template data<&UIConfig::button_UIE>("button_UIE"_hs)
                                                               .template data<&UIConfig::buttonCallback>("button"_hs)
                                                               .template data<&UIConfig::buttonTemp>("buttonTemp"_hs)
                                                               .template data<&UIConfig::disable_button>("disable_button"_hs)

                                                               .template data<&UIConfig::progressBar>("progressBar"_hs)
                                                               .template data<&UIConfig::progressBarEmptyColor>("progressBarEmptyColor"_hs)
                                                               .template data<&UIConfig::progressBarFullColor>("progressBarFullColor"_hs)
                                                               .template data<&UIConfig::progressBarMaxValue>("progressBarMaxValue"_hs)
                                                               .template data<&UIConfig::progressBarValueComponentName>("progressBarValueComponentName"_hs)
                                                               .template data<&UIConfig::progressBarValueFieldName>("progressBarValueFieldName"_hs)
                                                               .template data<&UIConfig::ui_object_updated>("ui_object_updated"_hs)

                                                               .template data<&UIConfig::buttonDelayStart>("buttonDelayStart"_hs)
                                                               .template data<&UIConfig::buttonDelay>("buttonDelay"_hs)
                                                               .template data<&UIConfig::buttonDelayProgress>("buttonDelayProgress"_hs)
                                                               .template data<&UIConfig::buttonDelayEnd>("buttonDelayEnd"_hs)
                                                               .template data<&UIConfig::buttonClicked>("buttonClicked"_hs)
                                                               .template data<&UIConfig::buttonDistance>("buttonDistance"_hs)

                                                               .template data<&UIConfig::tooltip>("tooltip"_hs)
                                                               .template data<&UIConfig::detailedTooltip>("detailedTooltip"_hs)
                                                               .template data<&UIConfig::onDemandTooltip>("onDemandTooltip"_hs)
                                                               .template data<&UIConfig::hover>("hover"_hs)

                                                               .template data<&UIConfig::force_focus>("force_focus"_hs)
                                                               .template data<&UIConfig::dynamicMotion>("dynamicMotion"_hs)
                                                               .template data<&UIConfig::choice>("choice"_hs)
                                                               .template data<&UIConfig::chosen>("chosen"_hs)
                                                               .template data<&UIConfig::chosen_vert>("chosen_vert"_hs)
                                                               .template data<&UIConfig::one_press>("one_press"_hs)
                                                               .template data<&UIConfig::draw_after>("draw_after"_hs)
                                                               .template data<&UIConfig::focusArgs>("focusArgs"_hs)
                                                               .template data<&UIConfig::updateFunc>("updateFunc"_hs)
                                                               .template data<&UIConfig::instaFunc>("instaFunc"_hs)

                                                               .template data<&UIConfig::ref_entity>("ref_entity"_hs)
                                                               .template data<&UIConfig::ref_component>("ref_component"_hs)
                                                               .template data<&UIConfig::ref_value>("ref_value"_hs)
                                                               .template data<&UIConfig::prev_ref_value>("prev_ref_value"_hs)

                                                               .template data<&UIConfig::text>("text"_hs)
                                                               .template data<&UIConfig::language>("language"_hs)
                                                               .template data<&UIConfig::verticalText>("verticalText"_hs)

                                                               .template data<&UIConfig::hPopup>("hPopup"_hs)
                                                               .template data<&UIConfig::hPopupConfig>("hPopupConfig"_hs)

                                                               .template data<&UIConfig::extend_up>("extend_up"_hs)
                                                               .template data<&UIConfig::resolution>("resolution"_hs)
                                                               .template data<&UIConfig::emboss>("emboss"_hs)
                                                               .template data<&UIConfig::line_emboss>("line_emboss"_hs)
                                                               .template data<&UIConfig::mid>("mid"_hs)
                                                               .template data<&UIConfig::noRole>("noRole"_hs)
                                                               .template data<&UIConfig::role>("role"_hs);

                                                           // static fields not allowed
                                                           // .template func<&UIConfig::functions>("functions"_hs);
                                                       });

        reflection::registerMetaForComponent<TransformConfig>([](auto meta)
                                                              { meta.type("TransformConfig"_hs) // Ensure type name matches the lookup string
                                                                    .template data<&TransformConfig::x>("x"_hs)
                                                                    .template data<&TransformConfig::y>("y"_hs)
                                                                    .template data<&TransformConfig::w>("w"_hs)
                                                                    .template data<&TransformConfig::h>("h"_hs)
                                                                    .template data<&TransformConfig::r>("r"_hs); });
    }

    void util::RemoveAll(entt::registry &registry, entt::entity entity)
    {
        // destroy all children, then itself
        auto *node = registry.try_get<transform::GameObject>(entity);
        if (node)
        {
            for (auto childEntry : node->children)
            {
                auto child = childEntry.second;
                RemoveAll(registry, child);
            }
            node->children.clear();
            node->orderedChildren.clear();
        }
        registry.destroy(entity);
    }

    // store the ui entity in a global list (which may or may not be necessary)
    void util::AddInstanceToRegistry(entt::registry &registry, entt::entity entity, const std::string &instanceType)
    {
        globals::globalUIInstanceMap[instanceType].push_back(entity);
    }

    // Function to calculate a small selection triangle
    std::vector<Vector2> util::GetChosenTriangleFromRect(float x, float y, float w, float h, bool vert)
    {
        float scale = 2.0f;
        float time = GetTime(); // Raylib's timer equivalent of G.TIMERS.REAL

        if (vert)
        {
            // Apply a subtle oscillation effect to x
            x += std::min(0.6f * std::sin(time * 9.0f) * scale + 0.2f, 0.0f);

            return {
                {x - 3.5f * scale, y + h / 2 - 1.5f * scale}, // Leftmost point
                {x - 0.5f * scale, y + h / 2},                // Middle point
                {x - 3.5f * scale, y + h / 2 + 1.5f * scale}  // Bottom-left point
            };
        }
        else
        {
            // Apply a subtle oscillation effect to y
            y += std::min(0.6f * std::sin(time * 9.0f) * scale + 0.2f, 0.0f);

            return {
                {x + w / 2 - 1.5f * scale, y - 4.0f * scale}, // Leftmost point
                {x + w / 2, y - 1.1f * scale},                // Tip of the triangle
                {x + w / 2 + 1.5f * scale, y - 4.0f * scale}  // Rightmost point
            };
        }
    }
    

    Color util::Darken(Color colour, float percent)
    {
        percent = (percent < 0.0f) ? 0.0f : (percent > 1.0f ? 1.0f : percent); // Clamp percent between 0 and 1
        return {
            static_cast<unsigned char>(colour.r * (1.0f - percent)),
            static_cast<unsigned char>(colour.g * (1.0f - percent)),
            static_cast<unsigned char>(colour.b * (1.0f - percent)),
            colour.a};
    }

    Color util::MixColours(const Color &C1, const Color &C2, float proportionC1)
    {
        proportionC1 = (proportionC1 < 0.0f) ? 0.0f : (proportionC1 > 1.0f ? 1.0f : proportionC1); // Clamp proportion

        return {
            static_cast<unsigned char>((C1.r * proportionC1 + C2.r * (1 - proportionC1))),
            static_cast<unsigned char>((C1.g * proportionC1 + C2.g * (1 - proportionC1))),
            static_cast<unsigned char>((C1.b * proportionC1 + C2.b * (1 - proportionC1))),
            static_cast<unsigned char>((C1.a * proportionC1 + C2.a * (1 - proportionC1)))};
    }

    Color util::AdjustAlpha(Color c, float newAlpha)
    {
        // Clamp newAlpha between 0.0 and 1.0, then convert to 0-255 range
        unsigned char alpha = static_cast<unsigned char>(newAlpha * 255.0f);
        return {c.r, c.g, c.b, alpha};
    }

    // be sure to call PushMatrix before calling this function
    // if applyOnlyTranslation is true, only translation will be applied, not rotation or scale
    void util::ApplyTransformMatrix(entt::registry &registry, entt::entity entity, std::shared_ptr<layer::Layer> layerPtr, std::optional<Vector2> addedOffset, bool applyOnlyTranslation)
    {

        auto &transform = registry.get<transform::Transform>(entity);

        if (applyOnlyTranslation)
        {
            layer::AddTranslate(layerPtr, transform.getVisualX(), transform.getVisualY());
            if (addedOffset)
            {
                layer::AddTranslate(layerPtr, addedOffset->x, addedOffset->y);
            }
            return;
        }

        layer::AddTranslate(layerPtr, transform.getVisualX() + transform.getVisualW() * 0.5, transform.getVisualY() + transform.getVisualH() * 0.5);
        
        if (addedOffset)
        {
            layer::AddTranslate(layerPtr, addedOffset->x, addedOffset->y);
        }

        layer::AddScale(layerPtr, transform.getVisualScaleWithHoverAndDynamicMotionReflected(), transform.getVisualScaleWithHoverAndDynamicMotionReflected());

        layer::AddRotate(layerPtr, transform.getVisualR() + transform.rotationOffset);

        layer::AddTranslate(layerPtr, -transform.getVisualW() * 0.5, -transform.getVisualH() * 0.5);
    }

    bool util::IsUIContainer(const entt::registry &registry, entt::entity entity)
    {
        auto *uiElement = registry.try_get<UIElementComponent>(entity);
        if (!uiElement)
            return false;
        // REVIEW: so RECT_SHAPE, TEXT, and OBJECT are not containers

        if (uiElement->UIT != UITypeEnum::VERTICAL_CONTAINER &&
            uiElement->UIT != UITypeEnum::HORIZONTAL_CONTAINER &&
            uiElement->UIT != UITypeEnum::ROOT)
        {
            return false;
        }
        return true;
    }
    auto util::sliderDiscrete(entt::registry &registry, entt::entity entity, float percentage) -> void
    {
        auto &node = registry.get<transform::GameObject>(entity);

        auto child = node.orderedChildren.begin(); // get first child, child is the slider, the entity is its parent
        auto &childNode = registry.get<transform::GameObject>(*child);
        auto &childUIConfig = registry.get<ui::UIConfig>(*child);
        auto &childTransform = registry.get<transform::Transform>(*child);

        node.state.dragEnabled = true;
        childNode.state.dragEnabled = true;

        if (percentage != 0.0f)
        {
            // TODO: definition should contain "SliderComponent" as component name, "value" as the field
            //  child is a slider, should have a slider component
            auto &sliderComponent = registry.get<ui::SliderComponent>(*child);

            sliderComponent.value = std::clamp(sliderComponent.value.value() + percentage * (sliderComponent.max.value() - sliderComponent.min.value()), sliderComponent.min.value(), sliderComponent.max.value());

            // Format the text with the correct decimal places
            sliderComponent.text = fmt::format("{:.{}f}", sliderComponent.value.value(), sliderComponent.decimal_places.value());

            childTransform.setActualW((sliderComponent.value.value() - sliderComponent.min.value()) / (sliderComponent.max.value() - sliderComponent.min.value()) * childTransform.getActualW());
        }
    }

    auto util::pointTranslate(Vector2 &point, const Vector2 &delta) -> void
    {
        point.x += delta.x;
        point.y += delta.y;
    }

    // Rotate a point around the origin by a given angle
    auto util::pointRotate(Vector2 &point, float angle) -> void
    {
        float cosAngle = std::cos(angle + PI / 2);
        float sinAngle = std::sin(angle + PI / 2);
        float originalX = point.x;
        float originalY = point.y;

        point.x = -originalY * cosAngle + originalX * sinAngle;
        point.y = originalY * sinAngle + originalX * cosAngle;
    }

    // location is implicitly 0, 0
    void util::emplaceOrReplaceNewRectangleCache(entt::registry &registry, entt::entity entity, int width, int height, float lineThickness, const int &type, std::optional<float> progress)
    {
        ZoneScopedN("ui::util::emplaceOrReplaceNewRectangleCache");
        auto &cache = registry.emplace_or_replace<RoundedRectangleVerticesCache>(entity);
        auto &node = registry.get<transform::GameObject>(entity);

        cache.w = width;
        cache.h = height;
        cache.lineThickness = lineThickness;
        cache.progress = progress;
        cache.renderTypeFlags = type;
        cache.shadowDisplacement = node.shadowDisplacement.value_or(Vector2{0, 0});

        AssertThat(cache.renderTypeFlags, Is().Not().EqualTo(RoundedRectangleVerticesCache_TYPE_NONE));

        auto [inner, outer] = GenerateInnerAndOuterVerticesForRoundedRect(lineThickness, static_cast<int>(cache.w), static_cast<int>(cache.h), cache);

        // width must be changed for generation to reflect progress
        if (progress)
        {
            AssertThat(cache.progress, Is().GreaterThanOrEqualTo(0.0f).And().LessThanOrEqualTo(1.0f));

            cache.innerVertices = inner;
            cache.outerVertices = outer;

            // clip the vertices at the progress value
            ClipRoundedRectVertices(cache.innerVertices, cache.w * progress.value());
            ClipRoundedRectVertices(cache.outerVertices, cache.w * progress.value());
        }

        // generate full rect vertices as well, for outlines
        cache.innerVerticesFull = inner;
        cache.outerVerticesFull = outer;
    }

    auto util::GenerateInnerAndOuterVerticesForRoundedRect(float lineThickness, int width, int height, RoundedRectangleVerticesCache &cache) -> std::pair<std::vector<Vector2>, std::vector<Vector2>> // inner, outer
    {
        // generation code here
        if (lineThickness <= 0.0f || width <= 2 * lineThickness || height <= 2 * lineThickness)
            return std::make_pair(std::vector<Vector2>{}, std::vector<Vector2>{});

        int cornerSize = getCornerSizeForRect(width, height);

        float outerRadius = (float)cornerSize;
        float innerRadius = fmaxf(outerRadius - lineThickness, 0); // Ensure inner radius doesn't go negative

        // NOTE: x and y are assumed to be at the origin.
        Rectangle outerRec = {(float)0.f, (float)0.f, (float)width, (float)height};
        Rectangle innerRec = {
            0 + lineThickness, 0 + lineThickness,
            width - 2 * lineThickness, height - 2 * lineThickness};

        const Vector2 outerCenters[4] = {
            {outerRec.x + outerRadius, outerRec.y + outerRadius},
            {outerRec.x + outerRec.width - outerRadius, outerRec.y + outerRadius},
            {outerRec.x + outerRec.width - outerRadius, outerRec.y + outerRec.height - outerRadius},
            {outerRec.x + outerRadius, outerRec.y + outerRec.height - outerRadius}};

        const Vector2 innerCenters[4] = {
            {innerRec.x + innerRadius, innerRec.y + innerRadius},
            {innerRec.x + innerRec.width - innerRadius, innerRec.y + innerRadius},
            {innerRec.x + innerRec.width - innerRadius, innerRec.y + innerRec.height - innerRadius},
            {innerRec.x + innerRadius, innerRec.y + innerRec.height - innerRadius}};

        const float angles[4] = {180.0f, 270.0f, 0.0f, 90.0f};
        const int numSteps = 4;
        float stepLength = 90.0f / (float)numSteps; // Angle step size

        std::vector<Vector2> outerVertices;
        std::vector<Vector2> innerVertices;

        // Generate stepped corners for both outlines
        for (int k = 0; k < 4; ++k)
        {
            float angle = angles[k];
            const Vector2 outerCenter = outerCenters[k];
            const Vector2 innerCenter = innerCenters[k];

            for (int i = 0; i < numSteps; i++)
            {
                Vector2 outerStart = {
                    outerCenter.x + cosf(DEG2RAD * angle) * outerRadius,
                    outerCenter.y + sinf(DEG2RAD * angle) * outerRadius};

                Vector2 outerEnd = {
                    outerCenter.x + cosf(DEG2RAD * (angle + stepLength)) * outerRadius,
                    outerCenter.y + sinf(DEG2RAD * (angle + stepLength)) * outerRadius};

                Vector2 innerStart = {
                    innerCenter.x + cosf(DEG2RAD * angle) * innerRadius,
                    innerCenter.y + sinf(DEG2RAD * angle) * innerRadius};

                Vector2 innerEnd = {
                    innerCenter.x + cosf(DEG2RAD * (angle + stepLength)) * innerRadius,
                    innerCenter.y + sinf(DEG2RAD * (angle + stepLength)) * innerRadius};

                Vector2 outerStep1, outerStep2, innerStep1, innerStep2;

                if (k == 0 || k == 2)
                {
                    // Top-left (0) and Bottom-right (2): swap order to maintain proper steps
                    outerStep1 = {outerEnd.x, outerStart.y};
                    outerStep2 = outerEnd;
                    innerStep1 = {innerEnd.x, innerStart.y};
                    innerStep2 = innerEnd;
                }
                else
                {
                    // Top-right (1) and Bottom-left (3): natural ordering works
                    outerStep1 = {outerStart.x, outerEnd.y};
                    outerStep2 = outerEnd;
                    innerStep1 = {innerStart.x, innerEnd.y};
                    innerStep2 = innerEnd;
                }

                // Store outer and inner vertices
                outerVertices.push_back(outerStart);
                outerVertices.push_back(outerStep1);
                outerVertices.push_back(outerStep1);
                outerVertices.push_back(outerStep2);

                innerVertices.push_back(innerStart);
                innerVertices.push_back(innerStep1);
                innerVertices.push_back(innerStep1);
                innerVertices.push_back(innerStep2);

                // Advance angle
                angle += stepLength;
            }
        }

        // Store the four straight edges of the rectangle outline
        Vector2 outerEdges[8] = {
            {outerRec.x + outerRadius, outerRec.y}, {outerRec.x + outerRec.width - outerRadius, outerRec.y}, // Top
            {outerRec.x + outerRec.width, outerRec.y + outerRadius},
            {outerRec.x + outerRec.width, outerRec.y + outerRec.height - outerRadius}, // Right
            {outerRec.x + outerRec.width - outerRadius, outerRec.y + outerRec.height},
            {outerRec.x + outerRadius, outerRec.y + outerRec.height}, // Bottom
            {outerRec.x, outerRec.y + outerRec.height - outerRadius},
            {outerRec.x, outerRec.y + outerRadius} // Left
        };

        Vector2 innerEdges[8] = {
            {innerRec.x + innerRadius, innerRec.y}, {innerRec.x + innerRec.width - innerRadius, innerRec.y}, // Top
            {innerRec.x + innerRec.width, innerRec.y + innerRadius},
            {innerRec.x + innerRec.width, innerRec.y + innerRec.height - innerRadius}, // Right
            {innerRec.x + innerRec.width - innerRadius, innerRec.y + innerRec.height},
            {innerRec.x + innerRadius, innerRec.y + innerRec.height}, // Bottom
            {innerRec.x, innerRec.y + innerRec.height - innerRadius},
            {innerRec.x, innerRec.y + innerRadius} // Left
        };

        for (int i = 0; i < 8; i += 2)
        {
            outerVertices.push_back(outerEdges[i]);
            outerVertices.push_back(outerEdges[i + 1]);

            innerVertices.push_back(innerEdges[i]);
            innerVertices.push_back(innerEdges[i + 1]);
        }

        return std::make_pair(innerVertices, outerVertices);
    }
    
    void util::DrawNPatchUIElement(std::shared_ptr<layer::Layer> layerPtr, entt::registry &registry, entt::entity entity, const Color &colorOverride, float parallaxModifier, std::optional<float> progress)
    {
        ZoneScopedN("ui::util::DrawNPatchUIElement");
        ::util::Profiler profiler("DrawNPatchUIElement");
        auto &transform = registry.get<transform::Transform>(entity);
        auto *uiConfig = registry.try_get<ui::UIConfig>(entity);
        auto &node = registry.get<transform::GameObject>(entity);
        
        //TODO: ignore or apply emboss?        
        std::optional<float> &emboss = uiConfig->emboss;
        
        
        const auto actualX = transform.getActualX() + node.layerDisplacement->x;
        const auto actualY = transform.getActualY() + node.layerDisplacement->y;
        const auto actualW = transform.getActualW();
        const auto actualH = transform.getActualH();
        const auto visualW = transform.getVisualW();
        const auto visualH = transform.getVisualH();
        
        // shadow
        float baseExaggeration = globals::BASE_SHADOW_EXAGGERATION;
        float heightFactor = 1.0f + node.shadowHeight.value_or(0.f); // Increase effect based on height

        // Adjust displacement using shadow height
        float shadowOffsetX = node.shadowDisplacement->x * baseExaggeration * heightFactor;
        float shadowOffsetY = node.shadowDisplacement->y * baseExaggeration * heightFactor;
        
        // if this is not 1, then we display progress-bar type tinting
        auto progressVal = progress.value_or(1.0f);
        
        auto nPatchInfo = uiConfig->nPatchInfo.value_or(NPatchInfo{});
        auto nPatchAtlas =  uiConfig->nPatchSourceTexture.value();
        
        // draw shadow first
        if (uiConfig->shadow)
        {
            layer::AddPushMatrix(layerPtr);
            
            util::ApplyTransformMatrix(registry, entity, layerPtr, Vector2{-shadowOffsetX * parallaxModifier, -shadowOffsetY * parallaxModifier}, false);

            Color colorToUse{};

            // if a shadow override exists, use it
            colorToUse = (uiConfig->shadowColor.value_or(Fade(BLACK, 0.4f)));

            // filled shadow
            layer::AddRenderNPatchRect(layerPtr, nPatchAtlas, nPatchInfo, Rectangle{0, 0, visualW * progressVal, visualH}, {0, 0}, 0.f, colorToUse);
            
            //TODO: resize the shadow to match the progress value?
            //TODO: how to do rotation later?

            layer::AddPopMatrix(layerPtr);
        }
        
        // then draw the npatch element itself
        layer::AddPushMatrix(layerPtr);
        
        util::ApplyTransformMatrix(registry, entity, layerPtr, Vector2{0, 0}, false);

        // layer::AddTranslate(layerPtr, actualX, actualY);

        Color colorToUse{};

        // if an fill override exists, use it
        colorToUse = colorOverride;

        // filled
        layer::AddRenderNPatchRect(layerPtr, nPatchAtlas, nPatchInfo, Rectangle{0, 0, visualW, visualH}, {0, 0}, 0.f, colorToUse);
        layer::AddPopMatrix(layerPtr);

        // fill progress, if there is any
        if (progress.has_value())
        {
            layer::AddPushMatrix(layerPtr);

            util::ApplyTransformMatrix(registry, entity, layerPtr, Vector2{0, 0}, false);

            Color colorToUse{};

            colorToUse = (uiConfig->progressBarFullColor.value_or(RED));

            // not shadow, ensure color is not translucent
            
            //TODO: i probably just want an overlay tinting of some sort over the rect, not actually ninepatch.

            // filled progress
            float shrink = globals::UI_PROGRESS_BAR_INSET_PIXELS;
            float newW = visualW * progressVal - 2 * shrink;
            float newH = visualH - 2 * shrink;

            newW = std::max(0.0f, newW);
            newH = std::max(0.0f, newH);

            // Center offset: translate before drawing
            float translateX = (visualW * progressVal - newW) / 2.0f;
            float translateY = (visualH - newH) / 2.0f;

            layer::AddTranslate(layerPtr, translateX, translateY);

            layer::AddRenderNPatchRect(
                layerPtr,
                nPatchAtlas,
                nPatchInfo,
                Rectangle{0, 0, newW, newH},
                {0, 0}, // ✅ no offset needed inside the rect
                0.f,
                colorToUse
            );
            
            layer::AddPopMatrix(layerPtr);
        }
    }

    // parallaxModifier is multiplied by the ui element's shadow displacement (if it exists)
    // emboss is the number of pixels to shift the emboss effect down by, if emboss is active via flags
    // colorOverride is an optional color to override the config component's colors.
    // lineWidth, if provided, will replace the rectangle cache's line thickness value temporarily
    // TODO: how to add moving text on top of progress bars?
    // TODO: need to take rotation, scale, etc. into account, I think? check
    /**
     * @brief Draws a stepped rounded rectangle with various rendering options.
     *
     * @param layerPtr A shared pointer to the layer where the rectangle will be drawn.
     * @param registry The entity registry containing the components.
     * @param entity The entity for which the rectangle is being drawn.
     * @param type The type of rendering to be applied (e.g., fill, outline, emboss).
     * @param parallaxModifier A modifier for parallax effects.
     * @param colorOverrides A map of color overrides for different parts of the rectangle. Keys can be: "fill" (filled color), "outline" (outline color), "shadow," (shadow color), "outline_shadow" (outline shadow color), "emboss" (emboss effect color), "outline_emboss," (color for emboss effect for outline only), "progress" (color for progress bar fill, if any). If no color override is provided, the config comopnent's colors will be used, or just the defaults.
     * @param progress An optional progress value for rendering progress bars.
     * @param lineWidthOverride An optional override for the line width.
     */
    void util::DrawSteppedRoundedRectangle(std::shared_ptr<layer::Layer> layerPtr, entt::registry &registry, entt::entity entity, const int &type, float parallaxModifier, const std::unordered_map<std::string, Color> &colorOverrides, std::optional<float> progress, std::optional<float> lineWidthOverride)
    {
        ZoneScopedN("ui::util::DrawSteppedRoundedRectangle");
        auto &transform = registry.get<transform::Transform>(entity);
        auto *uiConfig = registry.try_get<ui::UIConfig>(entity);
        auto &node = registry.get<transform::GameObject>(entity);

        // TODO: debug layer displacement non-zero for certain entities
        //  SPDLOG_DEBUG("DrawSteppedRoundedRectangle for entity {}, layered displacement: ({}, {})", static_cast<int>(entity), node.layerDisplacement->x, node.layerDisplacement->y);

        AssertThat(uiConfig, Is().Not().EqualTo(nullptr));

        std::optional<float> &emboss = uiConfig->emboss;

        // Cache stored pixelated rect
        auto *rectCache = registry.try_get<RoundedRectangleVerticesCache>(entity);
        // TODO: this should take layered parallax into account as well as scale.

        const auto actualX = transform.getActualX() + node.layerDisplacement->x;
        const auto actualY = transform.getActualY() + node.layerDisplacement->y;
        const auto actualW = transform.getActualW();
        const auto actualH = transform.getActualH();
        const auto visualW = transform.getVisualW();
        const auto visualH = transform.getVisualH();

        // comparisons to detect if the cache is usable
        if (!rectCache
            // || rectCache->renderTypeFlags != type
            || (rectCache->innerVertices.empty() && rectCache->outerVertices.empty()) || std::abs(rectCache->w - visualW) > EPSILON || std::abs(rectCache->h - visualH) > EPSILON
            // || (node.shadowDisplacement.has_value() && (rectCache->shadowDisplacement != node.shadowDisplacement.value()))
            || std::fabs(rectCache->progress.value() - progress.value_or(1.0f)) > EPSILON
            || (lineWidthOverride.has_value() && std::abs(rectCache->lineThickness - lineWidthOverride.value() > EPSILON)) || (uiConfig->outlineThickness.has_value() && std::abs(rectCache->lineThickness - uiConfig->outlineThickness.value()) > EPSILON))
        {
             SPDLOG_DEBUG("Regenerating cache for rounded rectangle");
            //  regenerate cache
            emplaceOrReplaceNewRectangleCache(registry, entity, visualW, visualH, uiConfig->outlineThickness.value_or(1.0f), type, progress.value_or(1.0f));
        }

        rectCache = registry.try_get<RoundedRectangleVerticesCache>(entity);
        AssertThat(rectCache, Is().Not().EqualTo(nullptr));

        // render the vertices using flags, parallax, emboss thickness, type flags

        // if progress 0, don't render anything
        if (rectCache->progress.value() <= 0.0f)
            return;

        // shadow
        float baseExaggeration = globals::BASE_SHADOW_EXAGGERATION;
        float heightFactor = 1.0f + node.shadowHeight.value_or(0.f); // Increase effect based on height

        // Adjust displacement using shadow height
        float shadowOffsetX = node.shadowDisplacement->x * baseExaggeration * heightFactor;
        float shadowOffsetY = node.shadowDisplacement->y * baseExaggeration * heightFactor;

        auto progressVal = rectCache->progress.value_or(1.0f);
        
        if (progress)
        {
            // SPDLOG_DEBUG("Progress value provided: {}", progress.value());
        }

        if (type & RoundedRectangleVerticesCache_TYPE_FILL && uiConfig->shadow)
        {
            ZoneScopedN("ui::util::DrawSteppedRoundedRectangle shadow fill");
            
            layer::AddPushMatrix(layerPtr);
            
            util::ApplyTransformMatrix(registry, entity, layerPtr, Vector2{-shadowOffsetX * parallaxModifier, -shadowOffsetY * parallaxModifier}, false);
            // layer::AddTranslate(layerPtr, -shadowOffsetX * parallaxModifier, -shadowOffsetY * parallaxModifier);

            // layer::AddTranslate(layerPtr, actualX, actualY);

            Color colorToUse{};

            // if a shadow override exists, use it
            if (colorOverrides.find("shadow") != colorOverrides.end())
            {
                colorToUse = colorOverrides.at("shadow");
            }
            else
            {
                colorToUse = (uiConfig->shadowColor.value_or(Fade(BLACK, 0.4f)));
            }
            
            // filled shadow
            // RenderRectVerticesFilledLayer(layerPtr, Rectangle{0, 0, rectCache->w * progressVal, rectCache->h}, rectCache->outerVerticesFull, colorToUse);
            layer::AddRenderRectVerticesFilledLayer(layerPtr, Rectangle{0, 0, rectCache->w * progressVal, rectCache->h}, false, entity, colorToUse);


            layer::AddPopMatrix(layerPtr);
        }
        else if (type & RoundedRectangleVerticesCache_TYPE_OUTLINE && uiConfig->outlineShadow)
        {
            ZoneScopedN("ui::util::DrawSteppedRoundedRectangle shadow outline");
            layer::AddPushMatrix(layerPtr);

            // layer::AddTranslate(layerPtr, -shadowOffsetX * parallaxModifier, -shadowOffsetY * parallaxModifier);
            // layer::AddTranslate(layerPtr, actualX, actualY);
            
            util::ApplyTransformMatrix(registry, entity, layerPtr, Vector2{-shadowOffsetX * parallaxModifier, -shadowOffsetY * parallaxModifier}, false);

            Color colorToUse{};

            // if an outline shadow override exists, use it
            if (colorOverrides.find("outline_shadow") != colorOverrides.end())
            {
                colorToUse = colorOverrides.at("outline_shadow");
            }
            else
            {
                colorToUse = (uiConfig->shadowColor.value_or(Fade(BLACK, 0.4f)));
            }

            ::util::Profiler profiler("RenderRectVerticlesOutlineLayer");
            // outline shadow
            layer::AddRenderRectVerticlesOutlineLayer(layerPtr, entity, colorToUse, true);
            // RenderRectVerticlesOutlineLayer(layerPtr, rectCache->outerVerticesFull, colorToUse, rectCache->innerVerticesFull);
            profiler.Stop();

            layer::AddPopMatrix(layerPtr);
        }

        // then emboss (y+ emboss value)
        if (type & RoundedRectangleVerticesCache_TYPE_EMBOSS)
        {
            ZoneScopedN("ui::util::DrawSteppedRoundedRectangle emboss fill");
            layer::AddPushMatrix(layerPtr);

            if (!emboss)
                SPDLOG_DEBUG("Emboss value not provided for emboss fill rectangle render flag");
            // layer::AddTranslate(layerPtr, 0, emboss.value_or(5.f) * parallaxModifier * uiConfig->scale.value_or(1.0f)); // shift y down for emboss effect

            // layer::AddTranslate(layerPtr, actualX, actualY);
            
            util::ApplyTransformMatrix(registry, entity, layerPtr, Vector2{0, emboss.value_or(5.f) * parallaxModifier * uiConfig->scale.value_or(1.0f)}, false);

            Color colorToUse{};

            // if an filled emboss override exists, use it
            if (colorOverrides.find("emboss") != colorOverrides.end())
            {
                colorToUse = colorOverrides.at("emboss");
            }
            else
            {
                colorToUse = (uiConfig->color.value_or(GRAY));
                // colorToUse = ColorBrightness(colorToUse, -0.5f);
                colorToUse = ColorTint(colorToUse, BLACK);
                colorToUse = BLACK;
            }

            // not shadow, ensure color is not translucent
            AssertThat(colorToUse.a, Is().EqualTo(255));

            // RenderRectVerticesFilledLayer(layerPtr, Rectangle{0, 0, rectCache->w, rectCache->h}, rectCache->outerVerticesFull, colorToUse);
            layer::AddRenderRectVerticesFilledLayer(layerPtr, Rectangle{0, 0, rectCache->w, rectCache->h}, false, entity, colorToUse);

            layer::AddPopMatrix(layerPtr);
        }
        else if (type & RoundedRectangleVerticesCache_TYPE_LINE_EMBOSS)
        {
            ZoneScopedN("ui::util::DrawSteppedRoundedRectangle emboss outline");
            layer::AddPushMatrix(layerPtr);

            if (!emboss)
                SPDLOG_DEBUG("Emboss value not provided for emboss outline rectangle render flag");
            // layer::AddTranslate(layerPtr, 0, emboss.value_or(5.f) * parallaxModifier * uiConfig->scale.value_or(1.0f)); // shift y down for emboss effect
            
            util::ApplyTransformMatrix(registry, entity, layerPtr, Vector2{0, emboss.value_or(5.f) * parallaxModifier * uiConfig->scale.value_or(1.0f)}, false);
// 
            // layer::AddTranslate(layerPtr, actualX, actualY);

            Color colorToUse{};

            // if an outline emboss override exists, use it
            if (colorOverrides.find("outline_emboss") != colorOverrides.end())
            {
                colorToUse = colorOverrides.at("outline_emboss");
            }
            else
            {
                colorToUse = (uiConfig->outlineColor.value_or(GRAY));
                // colorToUse = ColorBrightness(colorToUse, -0.5f);
                colorToUse = ColorTint(colorToUse, BLACK);
                colorToUse = BLACK;
            }

            // not shadow, ensure color is not translucent
            AssertThat(colorToUse.a, Is().EqualTo(255));

            // outline emboss
            // TODO: vertice usage changes depending on call.
            // RenderRectVerticlesOutlineLayer(layerPtr, rectCache->outerVertices, colorToUse, rectCache->innerVertices);
            layer::AddRenderRectVerticlesOutlineLayer(layerPtr, entity, colorToUse, false);

            layer::AddPopMatrix(layerPtr);
        }

        // then fill
        if (type & RoundedRectangleVerticesCache_TYPE_FILL)
        {
            ZoneScopedN("ui::util::DrawSteppedRoundedRectangle fill");
            // FIXME: testing with commenting out
            layer::AddPushMatrix(layerPtr);
            
            util::ApplyTransformMatrix(registry, entity, layerPtr, Vector2{0, 0}, false);

            // layer::AddTranslate(layerPtr, actualX, actualY);

            Color colorToUse{};

            // if an fill override exists, use it
            if (colorOverrides.find("fill") != colorOverrides.end())
            {
                colorToUse = colorOverrides.at("fill");
            }
            else
            {
                colorToUse = (uiConfig->color.value_or(WHITE));
            }

            // not shadow, ensure color is not translucent
            // AssertThat(colorToUse.a, Is().EqualTo(255));

            // filled
            layer::AddRenderRectVerticesFilledLayer(layerPtr, Rectangle{0, 0, rectCache->w * progressVal, rectCache->h}, false,  entity, colorToUse);
            layer::AddPopMatrix(layerPtr);
        }

        // fill progress, if there is any
        if (type & RoundedRectangleVerticesCache_TYPE_FILL && rectCache->innerVertices.size() > 0 && rectCache->outerVertices.size() > 0 && progress.has_value())
        {
            ZoneScopedN("ui::util::DrawSteppedRoundedRectangle progress fill");
            layer::AddPushMatrix(layerPtr);

            // layer::AddTranslate(layerPtr, actualX, actualY);
            
            util::ApplyTransformMatrix(registry, entity, layerPtr, Vector2{0, 0}, false);
            
            // shrink the inner vertices so they look outlined
            {
                float shrinkPx = globals::UI_PROGRESS_BAR_INSET_PIXELS;

                float targetW = rectCache->w * progressVal - 2.0f * shrinkPx;
                float targetH = rectCache->h - 2.0f * shrinkPx;

                // Prevent negative dimensions
                targetW = std::max(0.0f, targetW);
                targetH = std::max(0.0f, targetH);

                float scaleX = targetW / (rectCache->w * progressVal);
                float scaleY = targetH / rectCache->h;

                float centerX = (rectCache->w * progressVal) / 2.0f;
                float centerY = rectCache->h / 2.0f;

                layer::AddTranslate(layerPtr, centerX, centerY);       // move to center
                layer::AddScale(layerPtr, scaleX, scaleY);             // scale around center
                layer::AddTranslate(layerPtr, -centerX, -centerY);     // move back

            }

            Color colorToUse{};

            // if an fill progress bar override exists, use it
            if (colorOverrides.find("progress") != colorOverrides.end())
            {
                colorToUse = colorOverrides.at("progress");
            }
            else
            {
                colorToUse = (uiConfig->progressBarFullColor.value_or(GREEN));
            }

            // not shadow, ensure color is not translucent
            AssertThat(colorToUse.a, Is().EqualTo(255));

            // filled progress
            // RenderRectVerticesFilledLayer(layerPtr, Rectangle{0, 0, rectCache->w * progressVal, rectCache->h}, rectCache->outerVertices, colorToUse);
            layer::AddRenderRectVerticesFilledLayer(layerPtr, Rectangle{0, 0, rectCache->w * progressVal, rectCache->h}, true, entity, colorToUse);
            layer::AddPopMatrix(layerPtr);
        }
        // and ... or outline
        if (type & RoundedRectangleVerticesCache_TYPE_OUTLINE)
        {
            ZoneScopedN("ui::util::DrawSteppedRoundedRectangle outline");
            layer::AddPushMatrix(layerPtr);

            // layer::AddTranslate(layerPtr, actualX, actualY);
            
            util::ApplyTransformMatrix(registry, entity, layerPtr, Vector2{0, 0}, false);

            Color colorToUse{};

            // if an outline override exists, use it
            if (colorOverrides.find("outline") != colorOverrides.end())
            {
                colorToUse = colorOverrides.at("outline");
            }
            else
            {
                colorToUse = (uiConfig->outlineColor.value_or(WHITE));
            }

            // not shadow, ensure color is not translucent
            AssertThat(colorToUse.a, Is().EqualTo(255));

            // outline
            // RenderRectVerticlesOutlineLayer(layerPtr, rectCache->outerVerticesFull, colorToUse, rectCache->innerVerticesFull);
            layer::AddRenderRectVerticlesOutlineLayer(layerPtr, entity, colorToUse, true);

            layer::AddPopMatrix(layerPtr);
        }

    }

    void util::RenderRectVerticlesOutlineLayer(std::shared_ptr<layer::Layer> layerPtr, const std::vector<Vector2> &outerVertices, const Color color, const std::vector<Vector2> &innerVertices)
    {
        // Draw the outlines
        // Draw the filled outline
        layer::AddSetRLTexture(layerPtr, {0}, 0);
        layer::AddBeginRLMode(layerPtr, RL_TRIANGLES);

        // Draw quads between outer and inner outlines using two triangles each
        for (size_t i = 0; i < outerVertices.size(); i += 2)
        {

            // First triangle: Outer1 → Inner1 → Inner2
            layer::AddVertex(layerPtr, outerVertices[i], color);
            layer::AddVertex(layerPtr, innerVertices[i], color);
            layer::AddVertex(layerPtr, innerVertices[i + 1], color);

            // Second triangle: Outer1 → Inner2 → Outer2
            layer::AddVertex(layerPtr, outerVertices[i], color);
            layer::AddVertex(layerPtr, innerVertices[i + 1], color);
            layer::AddVertex(layerPtr, outerVertices[i + 1], color);
        }

        layer::EndRLMode();
    }

    void util::RenderRectVerticesFilledLayer(std::shared_ptr<layer::Layer> layerPtr, const Rectangle outerRec, const std::vector<Vector2> &outerVertices, const Color color)
    {

        ::util::Profiler profiler("RenderRectVerticesFilledLayer");

        layer::AddSetRLTexture(layerPtr, {0}, 0);
        layer::AddBeginRLMode(layerPtr, RL_TRIANGLES);

        // Center of the entire rectangle (for filling)
        Vector2 center = {outerRec.x + outerRec.width / 2.0f, outerRec.y + outerRec.height / 2.0f};
        // SPDLOG_DEBUG("RenderRectVerticesFilledLayer > Center: x: {}, y: {}", center.x, center.y);

        // Fill using the **outer vertices** and the **center**
        for (size_t i = 0; i < outerVertices.size(); i += 2)
        {
            // Triangle: Center → Outer1 → Outer2
            layer::AddVertex(layerPtr, center, color);
            layer::AddVertex(layerPtr, outerVertices[i + 1], color);
            layer::AddVertex(layerPtr, outerVertices[i], color);
        }

        layer::AddEndRLMode(layerPtr);

        profiler.Stop();
    }

    auto util::ClipRoundedRectVertices(std::vector<Vector2> &vertices, float clipX) -> void
    {
        // SPDLOG_DEBUG("Clipping vertices at x: {} for progress", clipX);
        for (auto &vertex : vertices)
        {
            if (vertex.x > clipX)
            {
                vertex.x = clipX; // Flatten to cut line
            }
        }
    }

    auto util::getCornerSizeForRect(int width, int height) -> float
    {
        // mininum corner size is 15
        return std::max(std::max(width, height) / 60.f, 12.f);
    }

}