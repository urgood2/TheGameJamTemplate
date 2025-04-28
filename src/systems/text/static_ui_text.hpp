#pragma once

#include <string>
#include <vector>
#include <tuple>
#include <optional>
#include <functional>


#include "util/common_headers.hpp"
#include "util/utilities.hpp"
#include "textVer2.hpp"

namespace static_ui_text_system {
    
    struct StaticStyledTextSegment {
        std::string text;
        Color textColor = WHITE;
        Color backgroundColor = {0, 0, 0, 0};
    };
    
    struct StaticStyledTextLine {
        std::vector<StaticStyledTextSegment> segments;
    };
    
    struct StaticStyledText {
        std::vector<StaticStyledTextLine> lines; // 🛑 Group by line
        float scale = 1.0f;
        Vector2 position;
    };
    
    void splitTextByNewlines(const std::string& text,
        StaticStyledTextLine& currentLine,
        StaticStyledText& result,
        const StaticStyledTextSegment* styleTemplate = nullptr) ;
    
    inline StaticStyledText parseStaticStyledText(const std::string& input, float maxWidth) {
        StaticStyledText result;
        StaticStyledTextLine currentLine;
    
        std::regex pattern(R"(\[(.*?)\]\((.*?)\))");
        std::smatch match;
        std::string remaining = input;
    
        while (std::regex_search(remaining, match, pattern)) {
            // Text before match (plain)
            if (match.position() > 0) {
                std::string plainText = remaining.substr(0, match.position());
                splitTextByNewlines(plainText, currentLine, result);
            }
    
            // Matched styled text
            std::string textContent = match[1];
            std::string effectsContent = match[2];
    
            StaticStyledTextSegment segment{};
            segment.textColor = WHITE;
            segment.backgroundColor = {0, 0, 0, 0};
            segment.text = ""; // Will fill later
    
            auto parsedEffects = TextSystem::Functions::splitEffects(effectsContent);
            if (parsedEffects.arguments.count("color")) {
                segment.textColor = util::getColor(parsedEffects.arguments["color"][0]);
                
            }
            if (parsedEffects.arguments.count("background")) {
                segment.backgroundColor = util::getColor(parsedEffects.arguments["background"][0]);
            }
    
            splitTextByNewlines(textContent, currentLine, result, &segment);
    
            remaining = match.suffix().str();
        }
    
        // Remaining plain text
        if (!remaining.empty()) {
            splitTextByNewlines(remaining, currentLine, result);
        }
    
        // Push final line if it has content
        if (!currentLine.segments.empty()) {
            result.lines.push_back(std::move(currentLine));
        }
    
        // Measure total width for scaling
        float maxLineWidth = 0.0f;
        for (auto& line : result.lines) {
            float lineWidth = 0.0f;
            for (auto& seg : line.segments) {
                Vector2 size = MeasureTextEx(GetFontDefault(), seg.text.c_str(), 20, 1);
                lineWidth += size.x;
            }
            if (lineWidth > maxLineWidth) {
                maxLineWidth = lineWidth;
            }
        }
    
        if (maxLineWidth > maxWidth) {
            result.scale = maxWidth / maxLineWidth;
        } else {
            result.scale = 1.0f;
        }
        //TODO: refer to uibox's text size handling to fix this 
        
        return result;
    }
    
    inline void splitTextByNewlines(const std::string& text,
        StaticStyledTextLine& currentLine,
        StaticStyledText& result,
        const StaticStyledTextSegment* styleTemplate) 
    {
        size_t start = 0;
        size_t pos = text.find('\n');

        while (pos != std::string::npos) {
        std::string chunk = text.substr(start, pos - start);
        if (!chunk.empty()) {
        StaticStyledTextSegment seg{};
        if (styleTemplate) seg = *styleTemplate;
        seg.text = chunk;
        currentLine.segments.push_back(seg);
        }

        // Push the completed line
        result.lines.push_back(std::move(currentLine));
        currentLine = StaticStyledTextLine{}; // start new line

        start = pos + 1;
        pos = text.find('\n', start);
        }

        // Final chunk after last newline (if any)
        if (start < text.length()) {
        StaticStyledTextSegment seg{};
        if (styleTemplate) seg = *styleTemplate;
        seg.text = text.substr(start);
        currentLine.segments.push_back(seg);
        }
    }

}