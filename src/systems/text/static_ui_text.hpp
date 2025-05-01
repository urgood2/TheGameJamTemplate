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
    std::map<std::string, TextSegmentArgumentType> parseAttributes(const std::string& attributeString) {
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

}