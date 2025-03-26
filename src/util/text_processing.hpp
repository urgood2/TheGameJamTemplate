//-----------------------------------------------------------------------------
// Purpose: Text processing utilities for color tags
//-----------------------------------------------------------------------------

#pragma once

#include <string>
#include <sstream>
#include <vector>
#include <stack>
#include <unordered_map>


#if defined(_WIN32)           
	#define NOGDI             // All GDI defines and routines
	#define NOUSER            // All USER defines and routines
#endif

#define SPDLOG_ACTIVE_LEVEL SPDLOG_LEVEL_DEBUG // compiler-time log level

#include "spdlog/spdlog.h" // SPD logging lib // or any library that uses Windows.h
#include "spdlog/sinks/basic_file_sink.h"

#if defined(_WIN32)           // raylib uses these names as function parameters
	#undef near
	#undef far
#endif

#include "../third_party/rlImGui/imgui.h"

namespace text_processing {

    struct TaggedSubstring {
        std::string text;
        ImVec4 color;
    };
    
    // Cache for processed strings
    std::unordered_map<std::string, std::vector<TaggedSubstring>> processedStringsCache;
    
    // forward delcarations
    inline auto findLineEnd(const std::string& text, float wrap_width) -> size_t;
    
    inline auto processTags(const std::string& input) -> std::vector<TaggedSubstring> {
        // Check the cache first
        auto cacheIt = processedStringsCache.find(input);
        if (cacheIt != processedStringsCache.end()) {
            return cacheIt->second;
        }
        
        std::vector<TaggedSubstring> result;
        std::istringstream stream(input);
        std::string token;
        std::stack<ImVec4> colors;
        colors.push(ImVec4(1.0f, 1.0f, 1.0f, 1.0f)); // Default color: white

        while (std::getline(stream, token, '[')) {
            std::size_t tagEnd = token.find(']');
            if (tagEnd != std::string::npos) {
                std::string tag = token.substr(0, tagEnd);
                token.erase(0, tagEnd + 1);

                if (tag == "/color") {
                    // If it's an end color tag, pop the current color
                    if (colors.size() > 1) { // Don't pop the default color
                        colors.pop();
                    } else {
                        // Error: unmatched end color tag
                        SPDLOG_ERROR("Unmatched end color tag in string: {}", input);
                        return result;
                    }
                }
                else {
                    int r, g, b;
                    if (sscanf(tag.c_str(), "color=#%02x%02x%02x", &r, &g, &b) == 3) {
                        // Push the new color onto the stack
                        ImVec4 newColor(r/255.0f, g/255.0f, b/255.0f, 1.0f);
                        colors.push(newColor);
                    } else {
                        // Error: malformed color tag
                        SPDLOG_ERROR("Malformed color tag in string: {}", input);
                        return result;
                    }
                }
            }

            if (!token.empty()) {
                result.push_back({token, colors.top()});
            }
        }

        if (colors.size() > 1) {
            // Error: unmatched start color tag
            SPDLOG_ERROR("Unmatched start color tag in string: {}", input);
        }
        
        // Store the result in the cache before returning it
        processedStringsCache[input] = result;
        
        // debug print contents of result, with numbered tokens
        
        SPDLOG_DEBUG("Processed string: {}", input);
        
        for (auto& s : result) {
            SPDLOG_DEBUG("text: {}, color: ({}, {}, {}, {})", s.text, s.color.x, s.color.y, s.color.z, s.color.w);
        }
        

        return result;
    }

    
    // method to compare two ImVec4 objects
    inline auto operator==(const ImVec4& lhs, const ImVec4& rhs) -> bool {
        return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z && lhs.w == rhs.w;
    }
    
    // != operator for two ImVec4 objects
    inline auto operator!=(const ImVec4& lhs, const ImVec4& rhs) -> bool {
        return !(lhs == rhs);
    }
    
    /// @brief Processes the given string for color tags in the format [color=#rrggbb]text[/color] (where color is in hex) and displays them in a single line (wrapped) using the ImGui::TextWrapped() function.
    /// @param input 
    /// @return 
    // inline auto displayTaggedTextImGuiWrapped(const std::string& input) -> void {
    //     auto substrings = processTags(input);
        
    //     if (substrings.empty()) {
    //         return;
    //     }

    //     ImGui::PushStyleColor(ImGuiCol_Text, substrings[0].color);
    //     ImGui::TextWrapped(substrings[0].text.c_str());
    //     ImGui::SameLine();

    //     for (int i = 1; i < substrings.size(); i++) {
    //         if (substrings[i].color != substrings[i-1].color) {
    //             ImGui::PopStyleColor();
    //             ImGui::PushStyleColor(ImGuiCol_Text, substrings[i].color);
    //         }

    //         ImGui::TextWrapped(substrings[i].text.c_str());
            
    //         if (i < substrings.size() - 1) {
    //             ImGui::SameLine();
    //         }
    //     }

    //     ImGui::PopStyleColor();
    // }
    
    // /// @brief  Processes the given string for color tags in the format [color=#rrggbb]text[/color] (where color is in hex) and displays them in a single line using the ImGui::Text() function (does not wrap text)
    // /// @param input 
    // /// @param alpha 
    // /// @param baseColor 
    // /// @return 
    inline auto displayTaggedTextImGui(const std::string& input, float wrap_position, float alpha = 1.f, ImVec4 baseColor=ImVec4(1, 1, 1, 1)) -> void {
        auto substrings = processTags(input);

        if (substrings.empty()) {
            ImGui::PushStyleColor(ImGuiCol_Text, baseColor);
            ImGui::PushTextWrapPos(wrap_position);
            
            ImGui::TextWrapped(input.c_str());
            
            ImGui::PopTextWrapPos();
            
            ImGui::PopStyleColor();
            return;
        }

        ImVec4 currentColor = substrings[0].color;
        currentColor.w *= alpha;
        ImGui::PushStyleColor(ImGuiCol_Text, currentColor);

        ImGui::PushStyleVar(ImGuiStyleVar_ItemSpacing, ImVec2(0.0f, 0.0f));  // Push zero item spacing
        
        
        bool newLineStarted{false};
        for (int i = 0; i < substrings.size(); i++) {
            if (substrings[i].color != currentColor) {
                ImGui::PopStyleColor();
                currentColor = substrings[i].color;
                currentColor.w *= alpha;
                ImGui::PushStyleColor(ImGuiCol_Text, currentColor);
            }

            std::string text = substrings[i].text;
            size_t text_len = text.size();
            
            while (text_len > 0) {
                float current_line_space = wrap_position - ImGui::GetCursorPosX();
                size_t line_end_pos = findLineEnd(text, current_line_space);

                std::string output = text.substr(0, line_end_pos);
                
                // only trim spaces if starting a new line
                if (newLineStarted) {
                    output.erase(0, output.find_first_not_of(' '));  // trim leading spaces
                    output.erase(output.find_last_not_of(' ') + 1);  // trim trailing spaces
                }
                
                ImGui::TextUnformatted(output.c_str());

                text = text.substr(line_end_pos);
                if (!text.empty() && text[0] == ' ') {
                    text = text.substr(1);
                }
                text_len = text.size();
                newLineStarted = true;
            }

            if (i < substrings.size() - 1 && text_len == 0) {
                ImGui::SameLine();
                newLineStarted = false;
            }
            else {
                newLineStarted = true;
            }
        }

        ImGui::PopStyleVar();  // Pop the item spacing style var

        ImGui::PopStyleColor();
    }



    
    
    inline auto findLineEnd(const std::string& text, float wrap_width) -> size_t {
        size_t last_space = std::string::npos; // Position of the last space in the line

        for (size_t i = 0; i < text.size(); ++i) {
            if (text[i] == ' ') {
                last_space = i;
            }

            // Get the size of the text from start to the current position
            ImVec2 size = ImGui::CalcTextSize(text.substr(0, i).c_str());

            // If the size exceeds the wrap width and we've found a space, break the line at the space
            if (size.x > wrap_width && last_space != std::string::npos) {
                return last_space;
            }
        }

        // If we've gone through the entire text without exceeding the wrap width, return the end of the text
        return text.size();
    }
}
