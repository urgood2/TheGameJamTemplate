#pragma once

#include <string>
#include <vector>
#include <tuple>
#include <optional>
#include <functional>
#include <map>
#include <regex>
#include <set>
#include <variant>

#include "systems/ui/ui_data.hpp"

#include "util/common_headers.hpp"
#include "util/utilities.hpp"
#include "textVer2.hpp"

namespace static_ui_text_system {
    
    using TextSegmentArgumentType = std::variant<std::string, float, int, Color, bool>; // Assuming Color is already defined
    
    enum class StaticStyledTextSegmentType {
        TEXT,
        IMAGE,
        ANIMATION
    };

    struct StaticStyledTextSegment {
        std::string text;
        std::map<std::string, TextSegmentArgumentType> attributes;
        bool isImage = false; // true if this segment is an image, not actual text -> phase out, use StaticStyledTextSegmentType instead
        StaticStyledTextSegmentType type = StaticStyledTextSegmentType::TEXT;
    };

    struct StaticStyledTextLine {
        std::vector<StaticStyledTextSegment> segments;
    };

    struct StaticStyledText {
        std::vector<StaticStyledTextLine> lines;
        float scale = 1.0f;
        Vector2 position;
    };

    // Helper function to parse attributes inside (color=red;background=blue)
    inline std::map<std::string, TextSegmentArgumentType> parseAttributes(const std::string& attributeString) {
        std::map<std::string, TextSegmentArgumentType> attributes;
        std::regex attrRegex(R"((\w+)\s*=\s*([^;]+))");
        auto words_begin = std::sregex_iterator(attributeString.begin(), attributeString.end(), attrRegex);
        auto words_end = std::sregex_iterator();

        for (auto it = words_begin; it != words_end; ++it) {
            std::smatch match = *it;
            std::string key = match[1].str();
            std::string value = match[2].str();
            
            // For now treat all values as string; you could improve by type inferring (int, float, Color)
            attributes[key] = value;
        }

        return attributes;
    }

    inline std::string trim(const std::string& s) {
        auto start = s.find_first_not_of(" \t\r\n");
        if (start == std::string::npos) return ""; // all spaces
    
        auto end = s.find_last_not_of(" \t\r\n");
        return s.substr(start, end - start + 1);
    }
    
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

    inline StaticStyledText parseText(const std::string& input) {
        StaticStyledText result;
        StaticStyledTextLine currentLine;

        std::regex pattern(R"(\[([\s\S]*?)\]\((.*?)\))", std::regex::ECMAScript);
        std::match_results<std::string::const_iterator> match;
        std::string remaining = input;
        size_t searchStart = 0;

        SPDLOG_DEBUG("Starting parseText, input size: {}", input.size());

        while (std::regex_search(remaining.cbegin() + searchStart, remaining.cend(), match, pattern))
        {
            size_t matchPos = match.position() + searchStart;
            size_t matchLen = match.length();

            SPDLOG_DEBUG("Match found: '{}' (text='{}', attributes='{}') at pos {}, len {}",
                        match.str(), match.str(1), match.str(2), matchPos, matchLen);

            // Text before match → plain text
            if (matchPos > searchStart) {
                std::string preText = remaining.substr(searchStart, matchPos - searchStart);
                SPDLOG_DEBUG("Processing plain text before match: '{}'", preText);

                size_t pos = 0;
                while (true) {
                    size_t newLinePos = preText.find('\n', pos);
                    if (newLinePos == std::string::npos) {
                        StaticStyledTextSegment segment{ preText.substr(pos), {} };
                        SPDLOG_DEBUG("Plain segment added: '{}'", segment.text);
                        currentLine.segments.push_back(segment);
                        break;
                    } else {
                        StaticStyledTextSegment segment{ preText.substr(pos, newLinePos - pos), {} };
                        SPDLOG_DEBUG("Plain segment added with line split: '{}'", segment.text);
                        currentLine.segments.push_back(segment);
                        result.lines.push_back(currentLine);
                        SPDLOG_DEBUG("Line pushed (plain text split)");
                        currentLine = StaticStyledTextLine{};
                        pos = newLinePos + 1;
                    }
                }
            }

            // Matched styled text
            std::string styledText = match[1].str();
            std::string attributeString = match[2].str();
            std::map<std::string, TextSegmentArgumentType> attributes = parseAttributes(attributeString);

            SPDLOG_DEBUG("Processing styled text: '{}', attributes raw: '{}'", styledText, attributeString);
            
            if (styledText == "img") {
                StaticStyledTextSegment segment{ "$IMAGE$", attributes };
                segment.isImage = true; // Mark this segment as an image
                segment.type = StaticStyledTextSegmentType::IMAGE;
                currentLine.segments.push_back(segment);
            } 
            else if (styledText == "anim") {
                StaticStyledTextSegment segment{ "$ANIMATION$", attributes };
                segment.type = StaticStyledTextSegmentType::ANIMATION;
                currentLine.segments.push_back(segment);
            }
            else {
                // Standard styled text segment
                size_t pos = 0;
                while (true) {
                    size_t newLinePos = styledText.find('\n', pos);
                    if (newLinePos == std::string::npos) {
                        StaticStyledTextSegment segment{ styledText.substr(pos), attributes };
                        SPDLOG_DEBUG("Styled segment added: '{}'", segment.text);
                        currentLine.segments.push_back(segment);
                        break;
                    } else {
                        StaticStyledTextSegment segment{ styledText.substr(pos, newLinePos - pos), attributes };
                        SPDLOG_DEBUG("Styled segment added with line split: '{}'", segment.text);
                        currentLine.segments.push_back(segment);
                        result.lines.push_back(currentLine);
                        SPDLOG_DEBUG("Line pushed (styled text split)");
                        currentLine = StaticStyledTextLine{};
                        pos = newLinePos + 1;
                    }
                }
            }

            searchStart = matchPos + matchLen;
        }

        // Remaining text after last match
        if (searchStart < remaining.size()) {
            std::string postText = remaining.substr(searchStart);
            SPDLOG_DEBUG("Processing remaining text after last match: '{}'", postText);

            size_t pos = 0;
            while (true) {
                size_t newLinePos = postText.find('\n', pos);
                if (newLinePos == std::string::npos) {
                    StaticStyledTextSegment segment{ postText.substr(pos), {} };
                    SPDLOG_DEBUG("Remaining plain segment added: '{}'", segment.text);
                    currentLine.segments.push_back(segment);
                    break;
                } else {
                    StaticStyledTextSegment segment{ postText.substr(pos, newLinePos - pos), {} };
                    SPDLOG_DEBUG("Remaining plain segment added with line split: '{}'", segment.text);
                    currentLine.segments.push_back(segment);
                    result.lines.push_back(currentLine);
                    SPDLOG_DEBUG("Line pushed (remaining plain text split)");
                    currentLine = StaticStyledTextLine{};
                    pos = newLinePos + 1;
                }
            }
        }

        // Final push
        if (!currentLine.segments.empty()) {
            result.lines.push_back(currentLine);
            SPDLOG_DEBUG("Final line pushed with {} segments", currentLine.segments.size());
        }

        SPDLOG_DEBUG("parseText finished, total lines: {}", result.lines.size());
        return result;
    }
    
    // ---- NEW: tiny handle you can keep alongside the UI ----
    struct TextUIHandle {
        entt::entity root{entt::null};                         // set after you instantiate the template
        std::unordered_map<std::string, entt::entity> idMap;   // fill after instantiation
    };

    // ---- NEW: safe extractors from attributes ----
    inline std::optional<std::string>
    getAttrString(const std::map<std::string, static_ui_text_system::TextSegmentArgumentType>& attrs,
                std::string_view key)
    {
        auto it = attrs.find(std::string(key));
        if (it == attrs.end()) return std::nullopt;
        if (std::holds_alternative<std::string>(it->second))
            return std::get<std::string>(it->second);
        return std::nullopt;
    }

    // Accept both id= and elementID= (elementID kept for back-compat)
    inline std::optional<std::string>
    getExplicitId(const std::map<std::string, static_ui_text_system::TextSegmentArgumentType>& attrs)
    {
        if (auto v = getAttrString(attrs, "id")) return v;
        if (auto v = getAttrString(attrs, "elementID")) return v;
        return std::nullopt;
    }

    // ---- NEW: deterministic fallback ids ----
    // Example: L2S0  (line 2, segment 0).  If wrapper is true: wrap-L2S0
    inline std::string makeFallbackId(int lineIdx, int segIdx, bool wrapper = false)
    {
        if (wrapper) return fmt::format("wrap-L{}S{}", lineIdx, segIdx);
        return fmt::format("L{}S{}", lineIdx, segIdx);
    }

    // ---- NEW: resolve final id (explicit if present, else fallback) ----
    inline std::string resolveNodeId(const std::map<std::string, static_ui_text_system::TextSegmentArgumentType>& attrs,
                                    int lineIdx, int segIdx, bool wrapper = false)
    {
        if (auto exp = getExplicitId(attrs)) return *exp;
        return makeFallbackId(lineIdx, segIdx, wrapper);
    }

    // ---- NEW: post-instantiation scan to populate handle.idMap ----
    // Call this once after your template -> entities pass finishes.
    // You must already store the string id in your runtime UIConfig component.
    /*
    How to use buildIdMapFromRoot:
    Pass a small lambda that returns a std::vector<entt::entity> of children for a given entity. That keeps this header independent of your exact child-storage. Example if you have ui::UIElement with children vector:
    
    auto traverseChildren = [](entt::registry& R, entt::entity e) -> std::vector<entt::entity> {
        if (R.valid(e) && R.any_of<ui::UIElement>(e)) {
            return R.get<ui::UIElement>(e).children;
        }
        return {};
    };
    buildIdMapFromRoot(registry, rootEntity, handle, traverseChildren);

    */
    template <typename TraverseFn>
    inline void buildIdMapFromRoot(entt::registry& R, entt::entity root,
                                TextUIHandle& handle,
                                TraverseFn&& traverseChildren)
    {
        handle.root = root;
        std::vector<entt::entity> stack{root};

        while (!stack.empty()) {
            auto e = stack.back();
            stack.pop_back();

            if (R.valid(e) && R.any_of<ui::UIConfig>(e)) {
                auto& cfg = R.get<ui::UIConfig>(e);
                if (!cfg.id->empty()) {
                    handle.idMap[cfg.id.value()] = e;
                }
            }

            // The caller supplies how to walk children (keeps this generic to your tree storage)
            for (entt::entity child : traverseChildren(R, e)) {
                if (child != entt::null) stack.push_back(child);
            }
        }
    }

    // Convenience: O(1) fetch by id
    inline entt::entity getTextNode(const TextUIHandle& h, std::string_view id)
    {
        if (auto it = h.idMap.find(std::string(id)); it != h.idMap.end()) return it->second;
        return entt::null;
    }
    
    // REPLACE your previous getTextFromString with this version.
    // It assigns ids onto every created node's UIConfig so you can
    // build an idMap after instantiation.
    inline auto getTextFromString(std::string text) -> ui::UIElementTemplateNode
    {
        auto parseResult = static_ui_text_system::parseText(text);
        auto rows = parseResult.lines.size();

        std::vector<ui::UIElementTemplateNode> textRowDefs{};
        textRowDefs.reserve(rows);

        for (int i = 0; i < static_cast<int>(rows); i++) {
            const auto& row = parseResult.lines[i];
            const int segments = static_cast<int>(row.segments.size());

            std::vector<ui::UIElementTemplateNode> textSegmentDefs{};
            textSegmentDefs.reserve(segments);

            using static_ui_text_system::StaticStyledTextSegmentType;

            for (int j = 0; j < segments; j++) {
                const auto& segment = row.segments[j];

                // Common: compute id early (used by all branches)
                const std::string segId = resolveNodeId(segment.attributes, i, j, /*wrapper*/ false);

                if (segment.type == StaticStyledTextSegmentType::IMAGE) {
                    // [img](uuid=gear.png;scale=0.8;fg=WHITE;shadow=false)
                    auto uuid = getAttrString(segment.attributes, "uuid").value_or("");
                    float scale = 1.0f;
                    if (auto s = getAttrString(segment.attributes, "scale"))  scale = std::stof(*s);
                    auto fgColorString = getAttrString(segment.attributes, "fg").value_or("WHITE");
                    bool shadow = getAttrString(segment.attributes, "shadow").value_or("false") == "true";
                    auto fgColor = util::getColor(fgColorString);

                    // now create a static animation object with uuid
                    auto imageObject = animation_system::createAnimatedObjectWithTransform(uuid, true, 0, 0);
                    auto &gameObjectComp = globals::registry.get<transform::GameObject>(imageObject);
                    if (!shadow) gameObjectComp.shadowDisplacement.reset();

                    auto imageDef = ui::UIElementTemplateNode::Builder::create()
                        .addType(ui::UITypeEnum::OBJECT)
                        .addConfig(
                            ui::UIConfig::Builder::create()
                                .addId(segId) // ---- NEW: store id on the node
                                .addObject(imageObject)
                                .addColor(fgColor)
                                .addScale(scale)
                                .addShadow(shadow)
                                .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER
                                        | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                                .build())
                        .build();

                    textSegmentDefs.push_back(imageDef);
                    continue;
                }
                else if (segment.type == StaticStyledTextSegmentType::ANIMATION) {
                    // [anim](uuid=...;scale=...;fg=...;shadow=...)
                    auto uuid = getAttrString(segment.attributes, "uuid").value_or("");
                    float scale = 1.0f;
                    if (auto s = getAttrString(segment.attributes, "scale"))  scale = std::stof(*s);
                    auto fgColorString = getAttrString(segment.attributes, "fg").value_or("WHITE");
                    bool shadow = getAttrString(segment.attributes, "shadow").value_or("false") == "true";
                    auto fgColor = util::getColor(fgColorString);

                    auto animObject = animation_system::createAnimatedObjectWithTransform(uuid, false, 0, 0);
                    auto &gameObjectComp = globals::registry.get<transform::GameObject>(animObject);
                    if (!shadow) gameObjectComp.shadowDisplacement.reset();

                    auto animDef = ui::UIElementTemplateNode::Builder::create()
                        .addType(ui::UITypeEnum::OBJECT)
                        .addConfig(
                            ui::UIConfig::Builder::create()
                                .addId(segId) // ---- NEW
                                .addObject(animObject)
                                .addColor(fgColor)
                                .addScale(scale)
                                .addShadow(shadow)
                                .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER
                                        | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                                .build())
                        .build();

                    textSegmentDefs.push_back(animDef);
                    continue;
                }

                // TEXT path
                auto textSegmentDef = getNewTextEntry(segment.text); // your existing helper

                // color override?
                if (auto colorStr = getAttrString(segment.attributes, "color")) {
                    auto color = util::getColor(*colorStr);
                    textSegmentDef.config.color = color;
                }

                // assign id on the text node before any wrapping
                textSegmentDef.config.id = segId; // ---- NEW

                // background wrapper?
                if (auto bgStr = getAttrString(segment.attributes, "background")) {
                    auto bg = util::getColor(*bgStr);
                    const std::string wrapId = resolveNodeId(segment.attributes, i, j, /*wrapper*/ true);

                    // Wrap the text node in a horizontal container to render background
                    auto wrapperDef = ui::UIElementTemplateNode::Builder::create()
                        .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
                        .addConfig(
                            ui::UIConfig::Builder::create()
                                .addId(wrapId) // ---- NEW: wrapper has its own id
                                .addColor(bg)
                                .addPadding(10.f)
                                .addEmboss(2.f)
                                .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER
                                        | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                                .build())
                        .addChild(textSegmentDef)
                        .build();

                    textSegmentDef = wrapperDef;
                }

                textSegmentDefs.push_back(textSegmentDef);
            } // segments

            // Row container (unchanged, but keep left/center alignment as you had)
            auto textRowDef = ui::UIElementTemplateNode::Builder::create()
                .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
                .addConfig(
                    ui::UIConfig::Builder::create()
                        .addPadding(1.f)
                        .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_LEFT
                                | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                        .build());

            for (auto &segmentDef : textSegmentDefs) {
                textRowDef.addChild(segmentDef);
            }
            textRowDefs.push_back(textRowDef.build());
        }

        // Final vertical container
        auto textDef = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addPadding(0.0f)
                    .addMaxWidth(300.f)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER
                            | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build());

        for (auto &rowDef : textRowDefs) textDef.addChild(rowDef);

        return textDef.build();
    }
    
    inline void debugDumpIds(const static_ui_text_system::StaticStyledText& parsed) {
    for (int i = 0; i < (int)parsed.lines.size(); ++i) {
        const auto& line = parsed.lines[i];
        for (int j = 0; j < (int)line.segments.size(); ++j) {
            const auto& seg = line.segments[j];
            const std::string segId = resolveNodeId(seg.attributes, i, j, false);
            const char* t = (seg.type == static_ui_text_system::StaticStyledTextSegmentType::TEXT) ? "TEXT" :
                            (seg.type == static_ui_text_system::StaticStyledTextSegmentType::IMAGE) ? "IMAGE" :
                            "ANIM";
            SPDLOG_INFO("seg [{}] line={} idx={} id='{}' text='{}'",
                        t, i, j, segId, seg.text);
            if (getAttrString(seg.attributes, "background")) {
                const std::string wrapId = resolveNodeId(seg.attributes, i, j, true);
                SPDLOG_INFO("wrap line={} idx={} id='{}'", i, j, wrapId);
            }
        }
    }
}



}