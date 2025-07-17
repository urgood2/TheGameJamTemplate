#include "textVer2.hpp"

#include "raylib.h"
#include <cstdlib>
#include <string>
#include <vector>
#include <map>
#include <functional>
#include <regex>
#include <iostream>
#include <spdlog/spdlog.h>

#include "rlgl.h"

#include "systems/ai/ai_system.hpp"
#include "systems/localization/localization.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"
#include "text_effects.hpp"

#include "util/common_headers.hpp"
#include "util/utilities.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/transform/transform.hpp"
#include "systems/collision/broad_phase.hpp"

#include "core/init.hpp"

#include "../../core/globals.hpp"

#include "systems/layer/layer_command_buffer.hpp"

#include "systems/scripting/binding_recorder.hpp"

#include "sol/sol.hpp"

namespace TextSystem
{

    auto exposeToLua(sol::state &lua) -> void {
        auto& rec = BindingRecorder::instance();


        //
        // 1) Create the top-level TextSystem table
        //
        sol::table ts = lua.create_table();
        lua["TextSystem"] = ts;

        // make sure the dumper emits:
        // local TextSystem = {}
        rec.add_type("TextSystem").doc = "Container for all text‐system types";
        
        // //
        // // 2) ParsedEffectArguments
        // //
        // ts.new_usertype<TextSystem::ParsedEffectArguments>("ParsedEffectArguments",
        //     sol::constructors<>(),
        //     "arguments", &TextSystem::ParsedEffectArguments::arguments
        // );

        //
        // 2) ParsedEffectArguments
        //
        ts.new_usertype<TextSystem::ParsedEffectArguments>(
            "ParsedEffectArguments",
            sol::constructors<>(),
            "arguments", &TextSystem::ParsedEffectArguments::arguments
        );

        // Record the fully-qualified class and its one method
        {
            auto& td = rec.add_type("TextSystem.ParsedEffectArguments");
            td.doc = "Holds parsed arguments for text effects";

            rec.record_method(
                "TextSystem.ParsedEffectArguments",
                MethodDef{
                    "arguments",
                    // signature: returns a vector of strings
                    "---@return std::vector<std::string> arguments # The parsed effect arguments",
                    // doc:
                    "Returns the list of raw effect arguments",
                    /* is_static */ false,
                    /* is_overload */ false
                }
            );
        }

        //
        // 3) Character
        //
        ts.new_usertype<TextSystem::Character>(
            "Character",
            sol::constructors<>(),
            "value",                    &TextSystem::Character::value,
            "overrideCodepoint",        &TextSystem::Character::overrideCodepoint,
            "rotation",                 &TextSystem::Character::rotation,
            "scale",                    &TextSystem::Character::scale,
            "size",                     &TextSystem::Character::size,
            "shadowDisplacement",       &TextSystem::Character::shadowDisplacement,
            "shadowHeight",             &TextSystem::Character::shadowHeight,
            "scaleXModifier",           &TextSystem::Character::scaleXModifier,
            "scaleYModifier",           &TextSystem::Character::scaleYModifier,
            "color",                    &TextSystem::Character::color,
            "offsets",                  &TextSystem::Character::offsets,
            "shadowDisplacementOffsets",&TextSystem::Character::shadowDisplacementOffsets,
            "scaleModifiers",           &TextSystem::Character::scaleModifiers,
            "customData",               &TextSystem::Character::customData,
            "offset",                   &TextSystem::Character::offset,
            "effects",                  &TextSystem::Character::effects,
            "parsedEffectArguments",    &TextSystem::Character::parsedEffectArguments,
            "index",                    &TextSystem::Character::index,
            "lineNumber",               &TextSystem::Character::lineNumber,
            "firstFrame",               &TextSystem::Character::firstFrame,
            "tags",                     &TextSystem::Character::tags,
            "pop_in",                   &TextSystem::Character::pop_in,
            "pop_in_delay",             &TextSystem::Character::pop_in_delay,
            "createdTime",              &TextSystem::Character::createdTime,
            "parentText",               &TextSystem::Character::parentText,
            "isFinalCharacterInText",   &TextSystem::Character::isFinalCharacterInText,
            "effectFinished",           &TextSystem::Character::effectFinished,
            "isImage",                  &TextSystem::Character::isImage,
            "imageShadowEnabled",       &TextSystem::Character::imageShadowEnabled,
            "spriteUUID",               &TextSystem::Character::spriteUUID,
            "imageScale",               &TextSystem::Character::imageScale,
            "fgTint",                   &TextSystem::Character::fgTint,
            "bgTint",                   &TextSystem::Character::bgTint
        );

        // Record the fully-qualified class
        {
            auto& td = rec.add_type("TextSystem.Character");
            td.doc = "Represents one rendered character in the text system";

            // Helper lambda to reduce repetition
            auto record_field = [&](const char* name, const char* desc){
                rec.record_method(
                    "TextSystem.Character",
                    MethodDef{
                        name,
                        std::string{"---@return any "} + name + " # " + desc,
                        std::string{"Gets the "} + desc,
                        /*is_static=*/false,
                        /*is_overload=*/false
                    }
                );
            };

            record_field("value",                  "character value");
            record_field("overrideCodepoint",      "override codepoint");
            record_field("rotation",               "rotation angle");
            record_field("scale",                  "scale factor");
            record_field("size",                   "glyph size");
            record_field("shadowDisplacement",     "shadow displacement");
            record_field("shadowHeight",           "shadow height");
            record_field("scaleXModifier",         "X-axis scale modifier");
            record_field("scaleYModifier",         "Y-axis scale modifier");
            record_field("color",                  "tint color");
            record_field("offsets",                "per-glyph offsets");
            record_field("shadowDisplacementOffsets","per-glyph shadow offsets");
            record_field("scaleModifiers",         "per-glyph scale modifiers");
            record_field("customData",             "user-defined data");
            record_field("offset",                 "global offset");
            record_field("effects",                "applied effects list");
            record_field("parsedEffectArguments",  "parsed effect arguments");
            record_field("index",                  "character index");
            record_field("lineNumber",             "line number");
            record_field("firstFrame",             "first frame timestamp");
            record_field("tags",                   "attached tags");
            record_field("pop_in",                 "pop-in flag");
            record_field("pop_in_delay",           "pop-in delay time");
            record_field("createdTime",            "creation timestamp");
            record_field("parentText",             "parent text object");
            record_field("isFinalCharacterInText", "is final character in its text");
            record_field("effectFinished",         "effect finished flag");
            record_field("isImage",                "is an image glyph");
            record_field("imageShadowEnabled",     "image shadow enabled");
            record_field("spriteUUID",             "sprite UUID");
            record_field("imageScale",             "image scale factor");
            record_field("fgTint",                 "foreground tint");
            record_field("bgTint",                 "background tint");
        }

        
        
        //
        // 4) effectFunctions map
        //
        sol::table ef = lua.create_table();
        for (auto& [name, fn] : TextSystem::effectFunctions) {
            ef[name] = fn;
        }
        ts["effectFunctions"] = ef;
        rec.record_property("TextSystem", PropDef{
            "effectFunctions",
            "{}",
            "Map of effect names to C++ functions"
        });

        //
        // 5) Text struct
        //
        ts.new_usertype<TextSystem::Text>("Text",
            sol::constructors<>(),
            "get_value_callback",              &TextSystem::Text::get_value_callback,
            "onStringContentUpdatedOrChangedViaCallback",
                                            &TextSystem::Text::onStringContentUpdatedOrChangedViaCallback,
            "effectStringsToApplyGloballyOnTextChange",
                                            &TextSystem::Text::effectStringsToApplyGloballyOnTextChange,
            "onFinishedEffect",                &TextSystem::Text::onFinishedEffect,
            "pop_in_enabled",                  &TextSystem::Text::pop_in_enabled,
            "shadow_enabled",                  &TextSystem::Text::shadow_enabled,
            "width",                           &TextSystem::Text::width,
            "height",                          &TextSystem::Text::height,
            "rawText",                         &TextSystem::Text::rawText,
            "characters",                      &TextSystem::Text::characters,
            "fontData",                        &TextSystem::Text::fontData,
            "fontSize",                        &TextSystem::Text::fontSize,
            "wrapEnabled",                     &TextSystem::Text::wrapEnabled,
            "wrapWidth",                       &TextSystem::Text::wrapWidth,
            "prevRenderScale",                 &TextSystem::Text::prevRenderScale,
            "renderScale",                     &TextSystem::Text::renderScale,
            "createdTime",                     &TextSystem::Text::createdTime,
            "effectStartTime",                 &TextSystem::Text::effectStartTime,
            "applyTransformRotationAndScale",  &TextSystem::Text::applyTransformRotationAndScale,
            "globalAlpha",                   &TextSystem::Text::globalAlpha,
            "type_id",                         []() { return entt::type_hash<TextSystem::Text>::value(); }
        );
        {
            auto& td = rec.add_type("TextSystem.Text");
            td.doc = "Main text object with content, layout, and effects";

            auto R = [&](const char* name){
                rec.record_method(
                    "TextSystem.Text",
                    MethodDef{
                        name,
                        std::string{"---@return any "} + name + " # raw value",
                        std::string{"Gets the raw "} + name,
                        /*is_static=*/false,
                        /*is_overload=*/false
                    }
                );
            };
            R("get_value_callback");
            R("onStringContentUpdatedOrChangedViaCallback");
            R("effectStringsToApplyGloballyOnTextChange");
            R("onFinishedEffect");
            R("pop_in_enabled");
            R("shadow_enabled");
            R("width");
            R("height");
            R("rawText");
            R("characters");
            R("fontData");
            R("fontSize");
            R("wrapEnabled");
            R("wrapWidth");
            R("prevRenderScale");
            R("renderScale");
            R("createdTime");
            R("effectStartTime");
            R("applyTransformRotationAndScale");
        }


        // 5a) TextAlignment sub-enum
        ts["TextAlignment"] = lua.create_table_with(
            "LEFT",      TextSystem::Text::Alignment::LEFT,
            "CENTER",    TextSystem::Text::Alignment::CENTER,
            "RIGHT",     TextSystem::Text::Alignment::RIGHT,
            "JUSTIFIED", TextSystem::Text::Alignment::JUSTIFIED
        );

        // Tell the recorder about TextSystem.TextAlignment as its own class
        auto& tdAlign = rec.add_type("TextSystem.TextAlignment");
        tdAlign.doc = "Enum of text alignment values";

        // Now record each member as a property on that type
        rec.record_property("TextSystem.TextAlignment", PropDef{ "LEFT",      "0", "Left-aligned text" });
        rec.record_property("TextSystem.TextAlignment", PropDef{ "CENTER",    "1", "Centered text" });
        rec.record_property("TextSystem.TextAlignment", PropDef{ "RIGHT",     "2", "Right-aligned text" });
        rec.record_property("TextSystem.TextAlignment", PropDef{ "JUSTIFIED", "3", "Justified text" });

        // 5b) TextWrapMode sub‐enum
        ts["TextWrapMode"] = lua.create_table_with(
            "WORD",      TextSystem::Text::WrapMode::WORD,
            "CHARACTER", TextSystem::Text::WrapMode::CHARACTER
        );

        // Declare the enum as its own type so the dumper emits `local TextSystem.TextWrapMode = {}`
        auto& tdWrap = rec.add_type("TextSystem.TextWrapMode");
        tdWrap.doc = "Enum of text wrap modes";

        // Record each enum member as a real constant field
        rec.record_property("TextSystem.TextWrapMode", PropDef{
            "WORD",
            std::to_string(static_cast<int>(TextSystem::Text::WrapMode::WORD)),
            "Wrap on word boundaries"
        });
        rec.record_property("TextSystem.TextWrapMode", PropDef{
            "CHARACTER",
            std::to_string(static_cast<int>(TextSystem::Text::WrapMode::CHARACTER)),
            "Wrap on individual characters"
        });

        //
        // 6) Builders subtable
        //
        sol::table builders = lua.create_table();
        ts["Builders"] = builders;
        builders.new_usertype<TextSystem::Builders::TextBuilder>("TextBuilder",
            sol::constructors<>(),
            "setRawText",     &TextSystem::Builders::TextBuilder::setRawText,
            "setFontData",    &TextSystem::Builders::TextBuilder::setFontData,
            "setOnFinishedEffect", &TextSystem::Builders::TextBuilder::setOnFinishedEffect,
            "setFontSize",    &TextSystem::Builders::TextBuilder::setFontSize,
            "setWrapWidth",   &TextSystem::Builders::TextBuilder::setWrapWidth,
            "setAlignment",   &TextSystem::Builders::TextBuilder::setAlignment,
            "setWrapMode",    &TextSystem::Builders::TextBuilder::setWrapMode,
            "setCreatedTime", &TextSystem::Builders::TextBuilder::setCreatedTime,
            "setPopInEnabled",&TextSystem::Builders::TextBuilder::setPopInEnabled,
            "build",          &TextSystem::Builders::TextBuilder::build
        );
        {
            rec.add_type("TextSystem.Builders");
            auto& td = rec.add_type("TextSystem.Builders.TextBuilder");
            td.doc = "Fluent builder for creating TextSystem.Text objects";
            auto Rb = [&](const char* name){
                rec.record_method(
                    "TextSystem.Builders.TextBuilder",
                    MethodDef{
                        name,
                        std::string{"---@param v any # argument for "} + name,
                        std::string{"Builder method "} + name,
                        /*is_static=*/false,
                        /*is_overload=*/false
                    }
                );
            };
            Rb("setRawText"); Rb("setFontData"); Rb("setOnFinishedEffect");
            Rb("setFontSize"); Rb("setWrapWidth"); Rb("setAlignment");
            Rb("setWrapMode"); Rb("setCreatedTime"); Rb("setPopInEnabled");
            Rb("build");
        }
        // 7) Functions subtable
        sol::table funcs = lua.create_table();
        ts["Functions"] = funcs;

        // make sure the dumper emits: local TextSystem.Functions = {}
        rec.add_type("TextSystem.Functions").doc = "Container for text system utility functions";

        rec.bind_function(lua, {"TextSystem","Functions"}, "adjustAlignment",
            &TextSystem::Functions::adjustAlignment,
            "---@param textEntity Entity # The text entity to adjust.\n"
            "---@return nil",
            "Adjusts text alignment based on calculated line widths."
        );

        rec.bind_function(lua, {"TextSystem","Functions"}, "splitEffects",
            &TextSystem::Functions::splitEffects,
            "---@param effects string # The combined effect string (e.g., '{shake}{color=red}').\n"
            "---@return table # A structured table of parsed effect arguments.",
            "Splits a combined effect string into segments."
        );

        rec.bind_function(lua, {"TextSystem","Functions"}, "createTextEntity",
                &TextSystem::Functions::createTextEntity,
            // LuaDoc
            "---@param text TextSystem.Text                # The text configuration object.\n"
            "---@param x number                            # The initial x-position.\n"
            "---@param y number                            # The initial y-position.\n"
            "---@param[opt] waiters table<string,function> # Optional map of wait-callbacks by alias.\n"
            "---@return Entity                             # The newly created text entity.\n",
            "Creates a new text entity in the world.  If you pass a table of callbacks—\n"
            "each value must be a function that returns true when its wait condition is met—\n"
            "they will be stored in the Text component under txt.luaWaiters[alias]."
        );

        rec.bind_function(lua, {"TextSystem","Functions"}, "calculateBoundingBox",
            &TextSystem::Functions::calculateBoundingBox,
            "---@param textEntity Entity # The text entity to measure.\n"
            "---@return Vector2 # The calculated bounding box (width, height).",
            "Calculates the text's bounding box."
        );

        rec.bind_function(lua, {"TextSystem","Functions"}, "CodepointToString",
            &TextSystem::Functions::CodepointToString,
            "---@param codepoint integer # The Unicode codepoint.\n"
            "---@return string",
            "Converts a codepoint to a UTF-8 string."
        );

        rec.bind_function(lua, {"TextSystem","Functions"}, "parseText",
            &TextSystem::Functions::parseText,
            "---@param textEntity Entity # The entity whose text component should be parsed.\n"
            "---@return nil",
            "Parses the raw string of a text entity into characters and applies effects."
        );

        // This lambda's documentation correctly matches its simplified signature for Lua.
        rec.bind_function(lua, {"TextSystem","Functions"}, "handleEffectSegment",
            [](entt::entity e, sol::table lineWidthsTbl, sol::object cxObj, sol::object cyObj, sol::this_state s){
                // stub: wrap or drop
            },
            "---@param e Entity\n"
            "---@param lineWidths table\n"
            "---@param cx? any\n"
            "---@param cy? any\n"
            "---@return nil",
            "Handles a single effect segment during parsing."
        );

        rec.bind_function(lua, {"TextSystem","Functions"}, "updateText",
            &TextSystem::Functions::updateText,
            "---@param textEntity Entity\n"
            "---@param dt number # Delta time.\n"
            "---@return nil",
            "Updates text state (e.g., for animated effects)."
        );

        rec.bind_function(lua, {"TextSystem","Functions"}, "renderText",
            &TextSystem::Functions::renderText,
            "---@param textEntity Entity # The text entity to render.\n"
            "---@param layerPtr Layer # The rendering layer.\n"
            "---@param debug? boolean # Optionally draw debug info.\n"
            "---@return nil",
            "Renders text to the screen."
        );

        rec.bind_function(lua, {"TextSystem","Functions"}, "clearAllEffects",
            &TextSystem::Functions::clearAllEffects,
            "---@param textEntity Entity\n"
            "---@return nil",
            "Clears all effects on a text entity."
        );

        rec.bind_function(lua, {"TextSystem","Functions"}, "applyGlobalEffects",
            &TextSystem::Functions::applyGlobalEffects,
            "---@param textEntity Entity\n"
            "---@param effectString string # The effect string to apply to all characters.\n"
            "---@return nil",
            "Applies global effects to text."
        );

        rec.bind_function(lua, {"TextSystem","Functions"}, "debugPrintText",
            &TextSystem::Functions::debugPrintText,
            "---@param textEntity Entity\n"
            "---@return nil",
            "Prints internal debug info for a text entity."
        );

        rec.bind_function(lua, {"TextSystem","Functions"}, "resizeTextToFit",
            &TextSystem::Functions::resizeTextToFit,
            "---@param textEntity Entity\n"
            "---@param targetWidth number\n"
            "---@param targetHeight number\n"
            "---@param centerLaterally? boolean\n"
            "---@param centerVertically? boolean\n"
            "---@return nil",
            "Resizes text to fit its container."
        );

        rec.bind_function(lua, {"TextSystem","Functions"}, "setTextScaleAndRecenter",
            &TextSystem::Functions::setTextScaleAndRecenter,
            "---@param textEntity Entity\n"
            "---@param renderScale number\n"
            "---@param targetWidth number\n"
            "---@param targetHeight number\n"
            "---@param centerLaterally boolean\n"
            "---@param centerVertically boolean\n"
            "---@return nil",
            "Sets text scale and recenters its origin."
        );

        rec.bind_function(lua, {"TextSystem","Functions"}, "resetTextScaleAndLayout",
            &TextSystem::Functions::resetTextScaleAndLayout,
            "---@param textEntity Entity\n"
            "---@return nil",
            "Resets text scale and layout to its original parsed state."
        );

        rec.bind_function(lua, {"TextSystem","Functions"}, "setText",
            &TextSystem::Functions::setText,
            "---@param textEntity Entity # The entity to modify.\n"
            "---@param newText string # The new raw text string.\n"
            "---@return nil",
            "Updates the raw text string and reparses the entity."
        );
    }

    std::map<std::string, std::function<void(float, Character &, const std::vector<std::string> &)>> effectFunctions;

    namespace Functions
    {
        
        // automatically runs parseText() on the given text configuration and returns a transform-enabled entity
        auto createTextEntity(const Text &text, float x, float y, sol::optional<sol::table> waitersOpt) -> entt::entity
        {
            auto entity = transform::CreateOrEmplace(&globals::registry, globals::gameWorldContainerEntity, x, y, 1, 1);
            auto &transform = globals::registry.get<transform::Transform>(entity);
            auto &gameObject = globals::registry.get<transform::GameObject>(entity);
            auto &textComp = globals::registry.emplace<Text>(entity, text);
            auto &layerOrder = globals::registry.emplace<layer::LayerOrderComponent>(entity);

            // update the text if there is a callback
            if (textComp.get_value_callback)
            {
                textComp.rawText = textComp.get_value_callback();

                // SPDLOG_DEBUG("Text value callback returned: {}", textComp.rawText);
            }
            
            if (effectFunctions.empty())
            {
                TextSystem::initEffects();
            }
            parseText(entity);

            // apply effects if any are set
            if (textComp.effectStringsToApplyGloballyOnTextChange.size() > 0)
            {
                for (auto &tag : textComp.effectStringsToApplyGloballyOnTextChange)
                {
                    applyGlobalEffects(entity, tag);
                    // SPDLOG_DEBUG("Applying global effects for tag: {}", tag);
                }
            }
            
            
            // 2) stash any lua callbacks into your Text component
            auto &txtComp = globals::registry.get<Text>(entity);
            if (waitersOpt) {
                sol::table tbl = *waitersOpt;
                for (auto &kv : tbl) {
                    // alias, raw Lua function
                    std::string alias     = kv.first.as<std::string>();
                    sol::function raw_fn  = kv.second;
        
                    // --- COROUTINE BOILERPLATE ---
                    // create a new thread (so each waiter has its own stack)
                    sol::thread thr = sol::thread::create(raw_fn.lua_state());
                    sol::state_view thread_view{ thr.state() };
                    // bind the raw function into that thread
                    thread_view["__waiter_fn"] = raw_fn;
                    // grab it back as a thread-local function
                    sol::function thread_fn  = thread_view["__waiter_fn"];
                    // finally wrap it in a coroutine
                    sol::coroutine co{ thread_fn };
                    // -------------------------------
        
                    // store it under its alias
                    txtComp.luaWaiters[alias] = std::move(co);
                    txtComp.luaWaitThreads[alias] = std::move(thr);
                }
            } else {
                // no table provided, search in the lua state
                
                // iterate through text.waitpoints and get the ones which are lua callbacks as a list
                std::vector<std::string> luaWaiters;
                for (const auto &wp : textComp.waitPoints) {
                    if (wp.type == Text::WaitPoint::Type::Lua) {
                        luaWaiters.push_back(wp.id);
                    }
                }
                
                for (const auto &alias : luaWaiters) {
                    sol::function raw_fn  = ai_system::masterStateLua[alias];
                    if (!raw_fn.valid()) {
                        spdlog::warn("TextSystem::createTextEntity: Lua callback '{}' not found in the global state, skipping.", alias);
                        continue;
                    }
                    // --- COROUTINE BOILERPLATE ---
                    // create a new thread (so each waiter has its own stack)
                    sol::thread thr = sol::thread::create(raw_fn.lua_state());
                    sol::state_view thread_view{ thr.state() };
                    // bind the raw function into that thread
                    thread_view["__waiter_fn"] = raw_fn;
                    // grab it back as a thread-local function
                    sol::function thread_fn  = thread_view["__waiter_fn"];
                    // finally wrap it in a coroutine
                    sol::coroutine co{ thread_fn };
                    // -------------------------------  
                    
                    // store it under its alias
                    txtComp.luaWaiters[alias] = std::move(co);
                    txtComp.luaWaitThreads[alias] = std::move(thr);
                }
            }
            
            textComp.createdTime = main_loop::mainLoop.realtimeTimer;
        

            //TODO: testing
            // gameObject.state.dragEnabled = true;
            // gameObject.state.hoverEnabled = true;
            // gameObject.state.collisionEnabled = true;
            // gameObject.state.clickEnabled = true;
            return entity;
        }
        
        

        #include <algorithm> // For std::min

        // Function to resize text entity to fit the given target width and height
        // also modifes the offset so that the text is still in the same location as before with respect to the top left corner
        // the centering is done by modifying the offset of the transform
        void resizeTextToFit(entt::entity textEntity, float targetWidth, float targetHeight, bool centerLaterally, bool centerVertically)
        {
            auto &transform = globals::registry.get<transform::Transform>(textEntity);
            auto &text = globals::registry.get<Text>(textEntity);
            auto &role = globals::registry.get<transform::InheritedProperties>(textEntity);
            
            auto [width, height] = calculateBoundingBox(textEntity);
            
            // calculate the scale factor to fit the target width and height
            float scaleX = targetWidth / width;
            float scaleY = targetHeight / height;
            float scale = std::min(scaleX, scaleY); // Use the smaller scale factor to maintain aspect ratio
            
            // apply the new scale
            text.renderScale = scale;
            
            // if necessary, center the text laterally and vertically
            if (centerLaterally)
            {
                role.offset->x = (targetWidth - width * scale) / 2.0f;
            }
            else 
            {
                role.offset->x = 0.0f; // Reset lateral offset if not centering
            }
            if (centerVertically)
            {
                role.offset->y = (targetHeight - height * scale) / 2.0f;
            }
            else 
            {
                role.offset->y = 0.0f; // Reset vertical offset if not centering
            }
        }

        
        /**
         * @brief Sets the text scale for a given entity and optionally recenters it within a target area.
         * 
         * @param textEntity The entity containing the text component to be scaled and repositioned.
         * @param renderScale The new scale to apply to the text's rendering.
         * @param targetWidth The width of the target area for optional horizontal centering.
         * @param targetHeight The height of the target area for optional vertical centering.
         * @param centerLaterally If true, the text will be horizontally centered within the target width.
         * @param centerVertically If true, the text will be vertically centered within the target height.
         * 
         * @details
         * This function adjusts the render scale of the text associated with the given entity. After
         * updating the scale, it recalculates the bounding box of the text to reflect the new dimensions.
         * If centering is enabled (via `centerLaterally` or `centerVertically`), the function adjusts the
         * entity's offset to position the text within the specified target area.
         */
        void setTextScaleAndRecenter(entt::entity textEntity, float renderScale, float targetWidth, float targetHeight, bool centerLaterally, bool centerVertically)
        {
            auto &transform = globals::registry.get<transform::Transform>(textEntity);
            auto &text = globals::registry.get<Text>(textEntity);
            auto &role = globals::registry.get<transform::InheritedProperties>(textEntity);

            // Set the new scale
            text.renderScale = renderScale;

            // Recalculate the bounding box with the new scale
            auto [width, height] = calculateBoundingBox(textEntity);  // should reflect new scale

            // Optional recentering
            if (centerLaterally)
            {
                role.offset->x = (targetWidth - width) / 2.0f;
            }
            else
            {
                role.offset->x = 0.0f;
            }

            if (centerVertically)
            {
                role.offset->y = (targetHeight - height) / 2.0f;
            }
            else
            {
                role.offset->y = 0.0f;
            }
        }


        /**
         * @brief Resets the render scale, transform size, and offsets of a text entity to default values.
         * 
         * @param textEntity The entity containing the text component to be reset.
         * 
         * @details
         * This function sets the render scale of the text to 1.0f, recalculates its bounding box using
         * the unscaled dimensions, resets the transform size to match the original unscaled text dimensions,
         * and clears any positional offsets.
         */
        void resetTextScaleAndLayout(entt::entity textEntity)
        {
            auto &transform = globals::registry.get<transform::Transform>(textEntity);
            auto &text = globals::registry.get<Text>(textEntity);
            auto &role = globals::registry.get<transform::InheritedProperties>(textEntity);

            // Reset render scale to default
            text.renderScale = 1.0f;

            // Recalculate the unscaled bounding box
            auto [width, height] = calculateBoundingBox(textEntity); // should now reflect scale = 1

            // Set transform size to match original dimensions
            transform.setActualW(width);
            transform.setActualH(height);

            // Reset offset to origin
            role.offset->x = 0.0f;
            role.offset->y = 0.0f;
        }



        Character createCharacter(entt::entity textEntity, int codepoint, const Vector2 &startPosition, const Font &font, float fontSize,
                                  float &currentX, float &currentY, float wrapWidth, Text::Alignment alignment,
                                  float &currentLineWidth, std::vector<float> &lineWidths, int index, int &lineNumber)
        {
            auto &text = globals::registry.get<Text>(textEntity);
            
            int utf8Size = 0;
            const char *utf8Char = CodepointToUTF8(codepoint, &utf8Size);
            std::string characterString(utf8Char, utf8Size); // Create a string with the exact size
            Vector2 charSize = MeasureTextEx(font, characterString.c_str(), fontSize, 1.0f);
            // apply renderscale
            charSize.x *= text.renderScale;
            charSize.y *= text.renderScale;

            // Check for line wrapping, do this only if character wrapping is enabled
            if (text.wrapMode == Text::WrapMode::CHARACTER && wrapWidth > 0 && (currentX - startPosition.x) + charSize.x > wrapWidth)
            {
                lineWidths.push_back(currentLineWidth); // Save the width of the completed line
                currentX = startPosition.x;             // Reset to the start of the line
                currentY += charSize.y;                 // Move to the next line
                currentLineWidth = 0.0f;                // Reset current line width
                lineNumber++;                           // Increment line number
            }

            // spdlog::debug("Creating character: '{}' (codepoint: {}), x={}, y={}, line={}", characterString, codepoint, currentX, currentY, lineNumber);

            Character character{};

            character.value = codepoint;
            character.offset.x =currentX- startPosition.x;
            character.offset.y = currentY - startPosition.y;
            character.size.x = charSize.x;
            character.size.y = charSize.y;
            character.index = index;
            character.lineNumber = lineNumber;
            character.color = WHITE;
            character.scale = 1.0f;
            character.rotation = 0.0f;
            character.createdTime = text.createdTime;

            // SPDLOG_DEBUG("Creating character: '{}' (codepoint: {}), x={}, y={}, line={}, offsetY={}, offsetX={}", characterString, codepoint, currentX, currentY, lineNumber, character.offset.y, character.offset.x);
            if (text.pop_in_enabled)
            {
                character.pop_in = 0.0f;
                character.pop_in_delay = index * 0.1f; // Staggered pop-in effect
            }

            currentX += text.fontData.spacing * text.renderScale + charSize.x;         // Advance X position (include spacing)
            currentLineWidth += charSize.x + text.fontData.spacing * text.renderScale; // Update line width
            return character;
        }

        void adjustAlignment(entt::entity textEntity, const std::vector<float> &lineWidths)
        {
            auto &text = globals::registry.get<Text>(textEntity);
            
            float scaledWrapWidth = text.wrapWidth / text.renderScale;
            
            // spdlog::debug("Adjusting alignment for text with alignment mode: {}", magic_enum::enum_name<Text::Alignment>(text.alignment));

            for (size_t line = 0; line < lineWidths.size(); ++line)
            {
                float leftoverWidth = scaledWrapWidth - lineWidths[line];
                // spdlog::debug("Line {}: leftoverWidth = {}, wrapWidth = {}, lineWidth = {}", line, leftoverWidth, text.wrapWidth, lineWidths[line]);

                if (leftoverWidth <= 0.0f)
                {
                    // spdlog::debug("Line {} fits perfectly, skipping alignment.", line);
                    continue; // Skip alignment for lines that perfectly fit
                }

                if (text.alignment == Text::Alignment::CENTER)
                { // Center alignment
                    // spdlog::debug("Applying center alignment for line {}", line);
                    for (auto &character : text.characters)
                    {
                        if (character.lineNumber == line)
                        {
                            // spdlog::debug("Before: Character '{}' at x={}", character.value, character.offset.x);
                            character.offset.x += leftoverWidth / 2.0f;
                            // spdlog::debug("After: Character '{}' at x={}", character.value, character.offset.x);
                        }
                    }
                }
                else if (text.alignment == Text::Alignment::RIGHT)
                { // Right alignment
                    // spdlog::debug("Applying right alignment for line {}", line);
                    for (auto &character : text.characters)
                    {
                        if (character.lineNumber == line)
                        {
                            auto currentLineWidth = lineWidths[line];
                            // spdlog::debug("Before: Character '{}' at x={}", character.value, character.offset.x);
                            character.offset.x = character.offset.x - currentLineWidth + text.wrapWidth;
                            // spdlog::debug("After: Character '{}' at x={}", character.value, character.offset.x);
                        }
                    }
                }
                else if (text.alignment == Text::Alignment::JUSTIFIED)
                { // Justified alignment
                    // spdlog::debug("Applying justified alignment for line {}", line);

                    size_t spacesCount = 0;
                    std::vector<size_t> spaceIndices; // To track indices of spaces for debugging

                    for (size_t i = 0; i < text.characters.size(); ++i)
                    {
                        const auto &character = text.characters[i];
                        if (character.lineNumber == line && character.value == ' ')
                        {
                            spacesCount++;
                            spaceIndices.push_back(i); // Save index of the space
                        }
                    }

                    // spdlog::debug("Line {}: spacesCount = {}", line, spacesCount);

                    if (spacesCount > 0)
                    {
                        float addedSpacePerSpace = leftoverWidth / spacesCount;
                        // spdlog::debug("Line {}: addedSpacePerSpace = {}", line, addedSpacePerSpace);

                        float cumulativeShift = 0.0f;

                        for (auto &character : text.characters)
                        {
                        
                            if (character.lineNumber == line)
                            {
                                if (character.value == ' ')
                                {
                                    // spdlog::debug("Space character at x={} gets additional space: {}", character.offset.x, addedSpacePerSpace);
                                    cumulativeShift += addedSpacePerSpace;
                                }

                                // spdlog::debug("Before: Character '{}' at x={}", character.value, character.offset.x);
                                character.offset.x += cumulativeShift;
                                // spdlog::debug("After: Character '{}' at x={}", character.value, character.offset.x);
                            }
                        }

                        // Debug: Print all space positions for this line
                        for (size_t index : spaceIndices)
                        {
                            auto &spaceCharacter = text.characters[index];
                            // spdlog::debug("Space character position: x={}, y={}, index={}", spaceCharacter.offset.x, spaceCharacter.offset.y, index);
                        }
                    }
                    else
                    {
                        // spdlog::warn("Line {} has no spaces, skipping justified alignment.", line);
                    }
                }
            }
        }

        Character createImageCharacter(entt::entity textEntity, const std::string &uuid, float width, float height, float scale,
            Color fg, Color bg,
            const Vector2 &startPosition, // Added to match createCharacter
            float &currentX, float &currentY,
            float wrapWidth,
            Text::Alignment alignment,
            float &currentLineWidth, std::vector<float> &lineWidths,
            int index, int &lineNumber)
        {
            auto &text = globals::registry.get<Text>(textEntity);

            // Scale image size based on render scale and imageScale
            float scaledWidth = width * scale * text.renderScale;
            float scaledHeight = height * scale * text.renderScale;

            // get max line height 
            float maxLineHeight = MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y;
            float lineHeight = text.fontSize * text.renderScale; // Approximate line height (same as text char height)
            float verticalOffset = (lineHeight - scaledHeight) * 0.5f;

            // Line wrapping check (same logic as character layout)
            if (text.wrapMode == Text::WrapMode::CHARACTER && wrapWidth > 0 &&
                (currentX - startPosition.x) + scaledWidth > wrapWidth)
            {
                lineWidths.push_back(currentLineWidth); // Save the width of the completed line
                currentX = startPosition.x;             // Reset X to start of line
                currentY += scaledHeight;               // Move Y down by line height
                currentLineWidth = 0.0f;                // Reset width accumulator
                lineNumber++;                           // Move to next line
            }

            Character imgChar;
            imgChar.value = 0;
            imgChar.isImage = true;
            imgChar.spriteUUID = uuid;
            imgChar.imageScale = scale;
            imgChar.fgTint = fg;
            imgChar.bgTint = bg;
            imgChar.offset.x = currentX - startPosition.x;
            imgChar.offset.y = currentY - startPosition.y + verticalOffset; // Adjust Y offset for image height, to center it vertically
            imgChar.size.x = scaledWidth;
            imgChar.size.y = scaledHeight;
            imgChar.index = index;
            imgChar.lineNumber = lineNumber;
            imgChar.color = WHITE;
            imgChar.scale = 1.0f;
            imgChar.rotation = 0.0f;
            imgChar.createdTime = text.createdTime;

            // SPDLOG_DEBUG("Creating image character '{}' @ {},{} size {}x{}", uuid, currentX, currentY, scaledWidth, scaledHeight);

            if (text.pop_in_enabled)
            {
                imgChar.pop_in = 0.0f;
                imgChar.pop_in_delay = index * 0.1f;
            }

            // Advance cursor and width
            currentX += scaledWidth + text.fontData.spacing * text.renderScale;
            currentLineWidth += scaledWidth + text.fontData.spacing * text.renderScale;

            return imgChar;
        }

        ParsedEffectArguments splitEffects(const std::string &effects)
        {
            // spdlog::debug("Splitting effects: {}", effects);
            ParsedEffectArguments parsedArguments;

            std::regex pattern(R"((\w+)(?:=([\-\w\.,]+))?)"); // Matches 'name' or 'name=arg,...'
            auto begin = std::sregex_iterator(effects.begin(), effects.end(), pattern);
            auto end = std::sregex_iterator();

            for (std::sregex_iterator i = begin; i != end; ++i)
            {
                std::smatch match = *i;
                std::string effectName = match[1];
                std::vector<std::string> args;

                if (match[2].matched)
                {
                    std::string argsString = match[2];
                    size_t pos = 0;
                    while ((pos = argsString.find(',')) != std::string::npos)
                    {
                        args.push_back(argsString.substr(0, pos));
                        argsString.erase(0, pos + 1);
                    }
                    args.push_back(argsString); // last arg
                }

                parsedArguments.arguments[effectName] = args;
            }

            return parsedArguments;
        }

        auto deleteCharacters(entt::entity textEntity)
        {
            auto &text = globals::registry.get<Text>(textEntity);
            // for (auto &character : text.characters)
            // {
            //     globals::registry.destroy(character);
            // }
            text.characters.clear();
        }

        void parseText(entt::entity textEntity)
        {
            // if characters are not cleared, delete them
            deleteCharacters(textEntity);

            auto &text = globals::registry.get<Text>(textEntity);
            auto &transform = globals::registry.get<transform::Transform>(textEntity);

            // float effectiveWrapWidth = text.wrapEnabled ? text.wrapWidth : std::numeric_limits<float>::max();
            float effectiveWrapWidth = text.wrapEnabled ? text.wrapWidth : std::numeric_limits<float>::max();
            effectiveWrapWidth /= text.renderScale;

            Vector2 textPosition = {transform.getActualX(), transform.getActualY()};
            
            // spdlog::debug("Parsing text: {}", text.rawText);
            // spdlog::debug("[preprocess] before: `{}`", text.rawText);
            preprocessTypingInlineTags(text);
            // spdlog::debug("[preprocess] after: `{}`", text.rawText);
            
            for (size_t i = 0; i < text.waitPoints.size(); ++i) {
            spdlog::debug(" waitPoint[{}] → type={}, id=`{}`, charIndex={}",
                            i,
                            magic_enum::enum_name<Text::WaitPoint::Type>(text.waitPoints[i].type),
                            text.waitPoints[i].id,
                            text.waitPoints[i].charIndex);
            }

            const char *rawText = text.rawText.c_str();

            std::regex pattern(R"(\[(.*?)\]\((.*?)\))"); // support [img](uuid=SPRITE_UUID;scale=1.2;fg=FFFFFF;bg=000000)
            std::smatch match;
            std::string regexText = text.rawText;

            const char *currentPos = regexText.c_str(); // Pointer to current position in the string

            float currentX = transform.getActualX();
            float currentY = transform.getActualY();

            std::vector<float> lineWidths; // To store widths of all lines
            float currentLineWidth = 0.0f;

            int codepointIndex = 0; // Index in the original text
            int lineNumber = 0;     // Line number for characters

            // Regex matching on raw UTF-8 text
            while (std::regex_search(regexText, match, pattern))
            {
                // spdlog::debug("Match found: {} with effects: {}", match[1].str(), match[2].str());

                // spdlog::debug("Match position: {}, length: {}", match.position(0), match.length(0));
                // spdlog::debug("Processing plain text before the match");
                // spdlog::debug("Plain text string: {}", std::string(currentPos, match.position(0)));

                // Process plain text before the match
                while (currentPos < regexText.c_str() + match.position(0))
                {
                    // get string at match position
                    std::string plainText(currentPos, match.position(0) - (currentPos - regexText.c_str()));

                    int codepointSize = 0;
                    int codepoint = GetCodepointNext(currentPos, &codepointSize);
                    if (codepoint == 0x01) {
                        // This is a wait-sentinel.  The *next* real character will have index=codepointIndex.
                        // Tie it back to the first unfilled waitPoint in FIFO order:
                        for (size_t w = 0; w < text.waitPoints.size(); ++w) {
                            auto &wp = text.waitPoints[w];
                            if (wp.charIndex == SIZE_MAX) {
                                wp.charIndex = codepointIndex;
                                spdlog::debug("[parseText] waitPoint[{}] → charIndex = {}",
                                              w, codepointIndex);
                                break;
                            }
                        }
                        // don’t produce a visible Character for the sentinel:
                        currentPos += codepointSize; // Advance pointer
                        // codepointIndex++;
                        continue;
                    }
                    

                    if (codepoint == '\n') // Handle line breaks
                    {
                        lineWidths.push_back(currentLineWidth); // Save current line width
                        currentX = transform.getActualX();             // Reset X position
                        currentY += MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y * text.renderScale;
                        currentLineWidth = 0.0f;
                        lineNumber++;
                    }

                    else if (codepoint == ' ' && text.wrapMode == Text::WrapMode::WORD) // Detect spaces, only for word wrap
                    {
                        // Look ahead to calculate the width of the next word
                        const char *lookaheadPos = currentPos + codepointSize;
                        float nextWordWidth = 0.0f;

                        // Accumulate the width of the next word
                        std::string lookaheadChar{};
                        std::string lookaheadCharString{};
                        while (*lookaheadPos && *lookaheadPos != ' ' && *lookaheadPos != '\n')
                        {
                            int lookaheadCodepointSize = 0;
                            int lookaheadCodepoint = GetCodepointNext(lookaheadPos, &lookaheadCodepointSize);
                            
                            if (codepoint == 0x01) {
                                // This is a wait-sentinel. 
                                // skip it and continue to the next character
                                
                                // Advance the lookahead pointer
                                lookaheadPos += lookaheadCodepointSize;
                                continue;
                            }

                            // Measure the size of the character and add to the word's width
                            lookaheadChar = CodepointToString(lookaheadCodepoint);
                            lookaheadCharString = lookaheadCharString + lookaheadChar;
                            Vector2 charSize = MeasureTextEx(text.fontData.font, lookaheadChar.c_str(), text.fontSize, 1.0f);
                            charSize.x *= text.renderScale;
                            charSize.y *= text.renderScale;
                            nextWordWidth += charSize.x;

                            // Advance the lookahead pointer
                            lookaheadPos += lookaheadCodepointSize;
                        }

                        // Check if the next word will exceed the wrap width
                        if ((currentX - transform.getActualX()) + nextWordWidth > effectiveWrapWidth)
                        {
                            // spdlog::debug("Wrap would have exceeded width: currentX={}, wrapWidth={}, nextWordWidth={}, exceeds={}", currentX, effectiveWrapWidth, nextWordWidth, (currentX - transform.getActualX()) + nextWordWidth);

                            // If the next word exceeds the wrap width, move to the next line
                            lineWidths.push_back(currentLineWidth);                           // Save current line width
                            currentX = transform.getActualX();                                       // Reset X position
                            currentY += MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y  * text.renderScale; // Move to the next line
                            currentLineWidth = 0.0f;
                            lineNumber++;

                            // // spdlog::debug("Word wrap: Moving to next line before processing space at x={}, y={}, line={}, with word {}",
                            //               currentX, currentY, lineNumber, lookaheadCharString);
                        }
                        else
                        {
                            auto character = createCharacter(textEntity, codepoint, textPosition, text.fontData.font, text.fontSize,
                                                             currentX, currentY, effectiveWrapWidth, text.alignment,
                                                             currentLineWidth, lineWidths, codepointIndex, lineNumber);
                            text.characters.push_back(character);
                        }
                    }
                    else if (codepoint == ' ' && text.wrapMode == Text::WrapMode::CHARACTER) // Detect spaces
                    {
                        if (currentX == transform.getActualX())
                        {
                            // Skip the space character at the beginning of the line
                            currentPos += codepointSize; // Advance pointer
                            codepointIndex++;
                            continue;
                        }
                        else
                        {
                            auto character = createCharacter(textEntity, codepoint, textPosition, text.fontData.font, text.fontSize,
                                                             currentX, currentY, effectiveWrapWidth, text.alignment,
                                                             currentLineWidth, lineWidths, codepointIndex, lineNumber);
                            text.characters.push_back(character);
                        }
                    }
                    else
                    {
                        auto character = createCharacter(textEntity, codepoint, textPosition, text.fontData.font, text.fontSize,
                                                         currentX, currentY, effectiveWrapWidth, text.alignment,
                                                         currentLineWidth, lineWidths, codepointIndex, lineNumber);
                        text.characters.push_back(character);
                    }

                    currentPos += codepointSize; // Advance pointer
                    codepointIndex++;
                }

                // Process matched effect text
                std::string effectText = match[1];
                std::string effects = match[2];
                

                if (effectText == "img")
                {
                    // this has to be an image character, ignore effect text
                    ParsedEffectArguments imgArgs = splitEffects(effects);

                    // extract image params
                    std::string uuid = imgArgs.arguments["uuid"].empty() ? "" : imgArgs.arguments["uuid"][0];
                    float scale = imgArgs.arguments["scale"].empty() ? 1.0f : std::stof(imgArgs.arguments["scale"][0]);
                    Color fgTint = util::getColor(imgArgs.arguments["fg"].empty() ? "WHITE" : imgArgs.arguments["fg"][0]);
                    Color bgTint = util::getColor(imgArgs.arguments["bg"].empty() ? "BLANK" : imgArgs.arguments["bg"][0]);
                    bool shadow = imgArgs.arguments["shadow"].empty() ? false : (imgArgs.arguments["shadow"][0] == "true" || imgArgs.arguments["shadow"][0] == "1");

                    // scaling for image
                    //TODO: fetch the sprite size, scale it down to fit the text heigth
                    float maxFontHeight = MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y * text.renderScale;
                    auto spriteFrame = init::getSpriteFrame(uuid);
                    auto desiredImageHeight = maxFontHeight * scale;
                    auto desiredImageWidth = spriteFrame.frame.width * (desiredImageHeight / spriteFrame.frame.height);
                    
                    // wrapping check
                    //TODO: maybe refactor this
                    if ((currentX - transform.getActualX()) + desiredImageWidth > effectiveWrapWidth)
                    {
                        lineWidths.push_back(currentLineWidth);
                        currentX = transform.getActualX();
                        currentY += maxFontHeight;
                        currentLineWidth = 0.0f;
                        lineNumber++;
                    } 

                    auto imageChar = createImageCharacter(textEntity, uuid, desiredImageWidth, desiredImageHeight, scale,
                        fgTint, bgTint,
                        textPosition, currentX, currentY, effectiveWrapWidth, text.alignment,
                        currentLineWidth, lineWidths, codepointIndex, lineNumber);

                    imageChar.imageShadowEnabled = shadow; // Set shadow effect for images
                    
                    text.characters.push_back(imageChar);

                    // move regexText and currentPos forward
                    regexText = match.suffix().str();
                    currentPos = regexText.c_str();
                    continue; // skip to next match
                }

                // spdlog::debug("Processing effect text: {}", effectText);

                // handle normal effect text
                const char *effectPos = effectText.c_str();
                ParsedEffectArguments parsedArguments = splitEffects(effects);
                handleEffectSegment(effectPos, lineWidths, currentLineWidth, currentX, textEntity, currentY, lineNumber, codepointIndex, parsedArguments);

                // Update regexText to process the suffix
                regexText = match.suffix().str();

                // FIXME: this does not set current position properly on the second matched effect text
                // TODO: get the position of the suffix and set currentPos to that
                //  Advance currentPos past the matched section
                //  currentPos = regexText.c_str() + (match.position(0) + match.length(0));
                currentPos = regexText.c_str();
            }

            // spdlog::debug("Processing plain text after the last match: {}", currentPos);
            while (*currentPos)
            {
                // get string at match position
                std::string plainText(currentPos, match.position(0) - (currentPos - regexText.c_str()));

                int codepointSize = 0;
                int codepoint = GetCodepointNext(currentPos, &codepointSize);
                
                if (codepoint == 0x01) {
                    // tie back to the first unfilled waitPoint
                    for (size_t w = 0; w < text.waitPoints.size(); ++w) {
                        auto &wp = text.waitPoints[w];
                        if (wp.charIndex == SIZE_MAX) {
                            wp.charIndex = codepointIndex;
                            spdlog::debug("[parseText] waitPoint[{}] → charIndex = {}",
                                          w, codepointIndex);
                            break;
                        }
                    }
                    // advance past sentinel
                    currentPos += codepointSize;
                    // codepointIndex++;
                    continue;
                }
                

                if (codepoint == '\n') // Handle line breaks
                {
                    lineWidths.push_back(currentLineWidth); // Save current line width
                    currentX = transform.getActualX();             // Reset X position
                    currentY += MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y  * text.renderScale;
                    currentLineWidth = 0.0f;
                    lineNumber++;
                }

                else if (codepoint == ' ' && text.wrapMode == Text::WrapMode::WORD) // Detect spaces
                {
                    // Look ahead to calculate the width of the next word
                    const char *lookaheadPos = currentPos + codepointSize;
                    float nextWordWidth = 0.0f;

                    // Accumulate the width of the next word
                    std::string lookaheadChar{};
                    std::string lookaheadCharString{};
                    while (*lookaheadPos && *lookaheadPos != ' ' && *lookaheadPos != '\n')
                    {
                        int lookaheadCodepointSize = 0;
                        int lookaheadCodepoint = GetCodepointNext(lookaheadPos, &lookaheadCodepointSize);
                        
                        if (lookaheadCodepoint == 0x01) {
                            // This is a wait-sentinel. 
                            // skip it and continue to the next character
                            
                            // Advance the lookahead pointer
                            lookaheadPos += lookaheadCodepointSize;
                            continue;
                        }

                        // Measure the size of the character and add to the word's width
                        lookaheadChar = CodepointToString(lookaheadCodepoint);
                        lookaheadCharString = lookaheadCharString + lookaheadChar;
                        Vector2 charSize = MeasureTextEx(text.fontData.font, lookaheadChar.c_str(), text.fontSize, 1.0f);
                        charSize.x *= text.renderScale;
                        charSize.y *= text.renderScale;
                        nextWordWidth += charSize.x;

                        // Advance the lookahead pointer
                        lookaheadPos += lookaheadCodepointSize;
                    }

                    // Check if the next word will exceed the wrap width
                    if ((currentX - transform.getActualX()) + nextWordWidth > effectiveWrapWidth)
                    {
                        // If the next word exceeds the wrap width, move to the next line
                        lineWidths.push_back(currentLineWidth);                           // Save current line width
                        currentX = transform.getActualX();                                       // Reset X position
                        currentY += MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y  * text.renderScale; // Move to the next line
                        currentLineWidth = 0.0f;
                        lineNumber++;

                        // spdlog::debug("Word wrap: Moving to next line before processing space at x={}, y={}, line={}, with word {}",
                        //               currentX, currentY, lineNumber, lookaheadCharString);
                    }
                    else
                    {
                        // FIXME: Ignore the space character if line changed
                        auto character = createCharacter(textEntity, codepoint, textPosition, text.fontData.font, text.fontSize,
                                                         currentX, currentY, effectiveWrapWidth, text.alignment,
                                                         currentLineWidth, lineWidths, codepointIndex, lineNumber);
                        text.characters.push_back(character);
                    }
                }
                else if (codepoint == ' ' && text.wrapMode == Text::WrapMode::CHARACTER) // Detect spaces
                {
                    // does adding the char take us over the wrap width?
                    if ((currentX - transform.getActualX()) + MeasureTextEx(text.fontData.font, " ", text.fontSize, 1.0f).x  * text.renderScale > effectiveWrapWidth)
                    {
                        // if so skip this space character

                        // Skip the space character at the beginning of the line
                        currentPos += codepointSize; // Advance pointer
                        codepointIndex++;
                        continue;
                    }
                    else
                    {
                        auto character = createCharacter(textEntity, codepoint, textPosition, text.fontData.font, text.fontSize,
                                                         currentX, currentY, effectiveWrapWidth, text.alignment,
                                                         currentLineWidth, lineWidths, codepointIndex, lineNumber);
                        text.characters.push_back(character);
                    }
                }
                else
                {
                    auto character = createCharacter(textEntity, codepoint, textPosition, text.fontData.font, text.fontSize,
                                                     currentX, currentY, effectiveWrapWidth, text.alignment,
                                                     currentLineWidth, lineWidths, codepointIndex, lineNumber);
                    text.characters.push_back(character);
                }

                currentPos += codepointSize; // Advance pointer
                codepointIndex++;
            }

            // Save the last line's width
            if (currentLineWidth > 0.0f)
            {
                lineWidths.push_back(currentLineWidth);
            }

            // Adjust alignment after parsing
            adjustAlignment(textEntity, lineWidths);

            // print all characters out for debugging
            for (const auto &character : text.characters)
            {
                int utf8Size = 0;
                // spdlog::debug("Character: '{}', x={}, y={}, line={}", CodepointToUTF8(character.value, &utf8Size), character.offset.x, character.offset.y, character.lineNumber);
            }

            auto ptr = std::make_shared<Text>(text);
            
            for (auto &character : text.characters)
            {
                character.parentText = ptr;
            }

            // get last character
            if (!text.characters.empty())
            {
                auto &lastCharacter = text.characters.back();
                lastCharacter.isFinalCharacterInText = true;
            }
            
            // enable pop-in effect if specified
            if (text.pop_in_enabled) {
                for (size_t i = 0; i < text.characters.size(); ++i) {
                    auto &ch = text.characters[i];
                    ch.pop_in       = 0.0f;
                    ch.pop_in_delay = i * text.typingSpeed;
                }
            }
              
        
            // gotta reflect final width and height
            auto [width, height] = calculateBoundingBox(textEntity);
            transform.setActualW(width);
            transform.setActualH(height);
            
            
            // spdlog::debug("— finished parseText(), total chars = {}", codepointIndex);
            for (size_t w = 0; w < text.waitPoints.size(); ++w) {
                auto &wp = text.waitPoints[w];
                spdlog::debug(" waitPoint[{}] id=`{}` → charIndex={}",
                            w, wp.id, wp.charIndex);
            }
        }

        void handleEffectSegment(const char *&effectPos, std::vector<float> &lineWidths, float &currentLineWidth, float &currentX, entt::entity textEntity, float &currentY, int &lineNumber, int &codepointIndex, TextSystem::ParsedEffectArguments &parsedArguments)
        {
            auto &text = globals::registry.get<Text>(textEntity);
            auto &transform = globals::registry.get<transform::Transform>(textEntity);
            Vector2 textPosition = {transform.getActualX(), transform.getActualY()};

            float effectiveWrapWidth = text.wrapEnabled ? text.wrapWidth : std::numeric_limits<float>::max();

            bool firstCharacter = true;
            while (*effectPos)
            {
                int codepointSize = 0;
                int codepoint = GetCodepointNext(effectPos, &codepointSize);
                
                if (codepoint == 0x01) {
                    // This is a wait-sentinel.  The *next* real character will have index=codepointIndex.
                    // Tie it back to the first unfilled waitPoint in FIFO order:
                    for (size_t w = 0; w < text.waitPoints.size(); ++w) {
                        auto &wp = text.waitPoints[w];
                        if (wp.charIndex == SIZE_MAX) {
                            wp.charIndex = codepointIndex;
                            spdlog::debug("[parseText] waitPoint[{}] → charIndex = {}",
                                          w, codepointIndex);
                            break;
                        }
                    }
                    // don’t produce a visible Character for the sentinel:
                    effectPos += codepointSize;
                    // codepointIndex++;
                    continue;
                }

                // check wrapping for first character
                if (firstCharacter && text.wrapMode == Text::WrapMode::CHARACTER) {

                }
                else if (firstCharacter && text.wrapMode == Text::WrapMode::WORD) {
                    // Look ahead to measure next word
                    const char *lookaheadPos = effectPos + codepointSize;
                    float nextWordWidth = 0.0f;
                    std::string lookaheadWord;
                    while (*lookaheadPos && *lookaheadPos != ' ' && *lookaheadPos != '\n')
                    {
                        int lookaheadSize = 0;
                        int lookaheadCodepoint = GetCodepointNext(lookaheadPos, &lookaheadSize);
                        if (lookaheadCodepoint == 0x01) {
                            // This is a wait-sentinel. 
                            // skip it and continue to the next character
                            
                            // Advance the lookahead pointer
                            lookaheadPos += lookaheadSize;
                            continue;
                        }
                        std::string utf8Char = CodepointToString(lookaheadCodepoint);
                        //TODO: spacing should omitted if the previous character is a space or the first character of the string
                        nextWordWidth += text.fontData.spacing + MeasureTextEx(text.fontData.font, utf8Char.c_str(), text.fontSize, 1.0f).x  * text.renderScale;
                        lookaheadPos += lookaheadSize;
                    }

                    //TODO: spacing seems off?

                    // just reposition in next line without skippin codepoint
                    if ((currentX - textPosition.x) + nextWordWidth > effectiveWrapWidth)
                    {
                        lineWidths.push_back(currentLineWidth);
                        currentX = textPosition.x;
                        currentY += MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y * text.renderScale;
                        currentLineWidth = 0.0f;
                        lineNumber++;
                    }
                }

                if (codepoint == '\n') // Explicit line break in effect text
                {
                    lineWidths.push_back(currentLineWidth);
                    currentX = textPosition.x;
                    currentY += MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y * text.renderScale;
                    currentLineWidth = 0.0f;
                    lineNumber++;
                }
                else if (codepoint == ' ')
                {
                    if (text.wrapMode == Text::WrapMode::WORD)
                    {
                        // Look ahead to measure next word
                        const char *lookaheadPos = effectPos + codepointSize;
                        float nextWordWidth = 0.0f;
                        std::string lookaheadWord;
                        while (*lookaheadPos && *lookaheadPos != ' ' && *lookaheadPos != '\n')
                        {
                            int lookaheadSize = 0;
                            int lookaheadCodepoint = GetCodepointNext(lookaheadPos, &lookaheadSize);
                            if (lookaheadCodepoint == 0x01) {
                                // This is a wait-sentinel. 
                                // skip it and continue to the next character
                                
                                // Advance the lookahead pointer
                                lookaheadPos += lookaheadSize;
                                continue;
                            }
                            std::string utf8Char = CodepointToString(lookaheadCodepoint);
                            //TODO: spacing should omitted if the previous character is a space or the first character of the string
                            nextWordWidth += text.fontData.spacing + MeasureTextEx(text.fontData.font, utf8Char.c_str(), text.fontSize, 1.0f).x * text.renderScale;
                            lookaheadPos += lookaheadSize;
                        }

                        //TODO: spacing seems off?

                        if ((currentX - textPosition.x) + nextWordWidth > effectiveWrapWidth)
                        {
                            lineWidths.push_back(currentLineWidth);
                            currentX = textPosition.x;
                            currentY += MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y * text.renderScale;
                            currentLineWidth = 0.0f;
                            lineNumber++;
                            effectPos += codepointSize;
                            codepointIndex++;
                            continue;
                        }
                    }
                    else if (text.wrapMode == Text::WrapMode::CHARACTER)
                    {
                        float spaceWidth = MeasureTextEx(text.fontData.font, " ", text.fontSize, 1.0f).x * text.renderScale;
                        if ((currentX - textPosition.x) + spaceWidth > effectiveWrapWidth)
                        {
                            // Skip space at start of line
                            effectPos += codepointSize;
                            codepointIndex++;
                            continue;
                        }
                    }
                }

                // Create and store character
                auto character = createCharacter(textEntity, codepoint, textPosition, text.fontData.font, text.fontSize,
                                                      currentX, currentY, effectiveWrapWidth, text.alignment,
                                                      currentLineWidth, lineWidths, codepointIndex, lineNumber);

                character.parsedEffectArguments = parsedArguments;

                for (const auto &[effectName, args] : parsedArguments.arguments)
                {
                    if (effectFunctions.count(effectName))
                    {
                        character.effects[effectName] = effectFunctions[effectName];
                    }
                }

                text.characters.push_back(character);
                effectPos += codepointSize;
                codepointIndex++;

                firstCharacter = false;
            }
        }
    
        void preprocessTypingInlineTags(Text &txt) {
            // canonicalize <typing,speed=...> → <typing=speed=...>
            auto interim = txt.rawText;
            interim = std::regex_replace(interim,
                std::regex(R"(<typing,speed=)"),
                "<typing=speed=");
            txt.rawText = interim;
            
            std::regex tagRe(R"(<(\w+)(?:=([^,>]+)(?:,([^>]+))?)?>)");
            std::smatch m;
            std::string s = txt.rawText;
        
            while (std::regex_search(s, m, tagRe)) {
                std::string name = m[1].str();
                std::string arg1 = m[2].matched ? m[2].str() : "";
                std::string arg2 = m[3].matched ? m[3].str() : "";
        
                if (name == "typing") {
                    txt.pop_in_enabled = true;
                    if (arg1.rfind("speed=",0) == 0)
                    txt.typingSpeed = std::stof(arg1.substr(6));
                    else if (arg2.rfind("speed=",0) == 0)
                    txt.typingSpeed = std::stof(arg2.substr(6));
                    
                    // Replace the entire tag with nothing
                    s.replace(m.position(0), m.length(0), "");
                }
                else if (name == "wait") {
                    Text::WaitPoint wp;
                    wp.type      = (arg1 == "key"   ? Text::WaitPoint::Key
                                    : arg1 == "mouse" ? Text::WaitPoint::Mouse
                                                    : Text::WaitPoint::Lua);
                                                    
                    // strip leading "id=" if present
                    std::string idPart = arg2;  
                    if (idPart.rfind("id=", 0) == 0) {
                        idPart.erase(0, 3);
                    }
                    wp.id = idPart;                // now just "KEY_ENTER" or your callback ID
                    wp.charIndex = SIZE_MAX;      // mark “not known yet”
                    txt.waitPoints.push_back(wp);
                    
                    
                    // Replace the entire tag with exactly 1 sentinel character:
                    s.replace(m.position(0), m.length(0), "\x01");
                }
        
            }
            txt.rawText = std::move(s);
        }
        
        
        void setText(entt::entity textEntity, const std::string &text)
        {
            auto &textComponent = globals::registry.get<Text>(textEntity);
            textComponent.rawText = text;
            textComponent.renderScale = 1.0f;
            
            textComponent.fontData = localization::getFontData();
            
            clearAllEffects(textEntity);
            deleteCharacters(textEntity);
            parseText(textEntity);

            if (textComponent.onStringContentUpdatedOrChangedViaCallback)
                textComponent.onStringContentUpdatedOrChangedViaCallback(textEntity);
        }

        void updateText(entt::entity textEntity, float dt)
        {
            
            auto &gameWorldTransform = globals::registry.get<transform::Transform>(globals::gameWorldContainerEntity);
            auto &textTransform = globals::registry.get<transform::Transform>(textEntity);

            auto &text = globals::registry.get<Text>(textEntity);
            // spdlog::debug("Updating text with delta time: {}", dt);

            // check value from lamdba function if there is one
            
            // check if renderscale changed
            if (text.renderScale != text.prevRenderScale) {
                spdlog::debug("Render scale changed from {} to {}", text.prevRenderScale, text.renderScale);
                text.prevRenderScale = text.renderScale;
                
                // update transform dimensions
                auto [width, height] = calculateBoundingBox(textEntity);
                textTransform.setActualW(width);
                textTransform.setActualH(height);
            }

            if (text.get_value_callback)
            {
                auto value = text.get_value_callback();
                if (value != text.rawText)
                {
                    // reset renderscale
                    text.renderScale = 1.0f;

                    // SPDLOG_DEBUG("Text value changed from '{}' to '{}'", text.rawText, value);
                    text.rawText = value;
                    clearAllEffects(textEntity);
                    parseText(textEntity);
                    for (auto tag : text.effectStringsToApplyGloballyOnTextChange) {
                        applyGlobalEffects(textEntity, tag);
                    }

                    // call callback
                    if (text.onStringContentUpdatedOrChangedViaCallback)
                    {
                        text.onStringContentUpdatedOrChangedViaCallback(textEntity);
                    }
                }
            }



            for (auto &character : text.characters)
            {
                // update shadow
                character.shadowDisplacement.x = ((textTransform.getActualX() + textTransform.getActualW() / 2) - (gameWorldTransform.getActualX() + gameWorldTransform.getActualW() / 2)) / (gameWorldTransform.getActualW() / 2) * 1.5f;

                
                
                // 1) see if any pending wait should fire
                for (auto &wp : text.waitPoints) {
                    if (!wp.triggered && wp.charIndex < text.characters.size() && character.index == wp.charIndex) {
                        auto &ch = text.characters[ wp.charIndex ];
                        // only start waiting once that char is fully popped in
                        // if (ch.pop_in >= 1.0f) {
                            bool fired = false;
                            switch (wp.type) {
                                case Text::WaitPoint::Key:
                                {
                                
                                    // strip any stray whitespace
                                    auto id = wp.id;
                                    id .erase(0, id.find_first_not_of(" \t\n\r"));
                                    id .erase(id.find_last_not_of(" \t\n\r") + 1);

                                    // try the cast
                                    auto maybeKey = magic_enum::enum_cast<KeyboardKey>(id, magic_enum::case_insensitive);

                                    if (!maybeKey) {
                                        spdlog::error("enum_cast failed for '{}', defaulting to KEY_NULL", id);
                                        // wp.key = KEY_NULL;
                                    } else {
                                        // wp.key = *maybeKey;
                                    }

                                    fired = IsKeyPressed(
                                        magic_enum::enum_cast<KeyboardKey>(wp.id, magic_enum::case_insensitive).value_or(KeyboardKey::KEY_NULL)
                                        );
                                    if (fired) {
                                        // update text created time to ensure pop-in animation is not blocked
                                        text.createdTime = GetTime();
                                    }
                                    break;
                                }
                                case Text::WaitPoint::Mouse:
                                {
                                    fired = IsMouseButtonPressed(
                                    magic_enum::enum_cast<MouseButton>(wp.id).value_or(MouseButton::MOUSE_BUTTON_SIDE)
                                    );
                                    if (fired) {
                                        // update text created time to ensure pop-in animation is not blocked
                                        text.createdTime = GetTime();
                                    }
                                    else {
                                        // if not fired, block everything until they press
                                        spdlog::debug("Mouse button '{}' not pressed, blocking text rendering", wp.id);
                                    }
                                    break;
                                }
                                case Text::WaitPoint::Lua:
                                {
                                    auto alias = wp.id;
                                    
                                    auto &co = text.luaWaiters.at(alias);
                                    if (!co.valid() ||
                                        co.status() != sol::call_status::yielded) {
                                    // either never created, or already completed — bail out
                                    return;
                                    }
                                    sol::protected_function_result result = co();
                                    if (!result.valid()) {
                                        sol::error err = result;
                                        spdlog::error("Coroutine error: {}", err.what());
                                        std::abort();
                                    }
                                    else if (co.status() == sol::call_status::yielded) {
                                        // still yielding (e.g. user did `wait(5)` internally)
                                        fired = false; // do not set wp.triggered to true
                                    }
                                    else {
                                        // coroutine finished; get its return value
                                        bool done = result.get<bool>();
                                        fired = true;
                                        
                                        // update text created time to ensure pop-in animation is not blocked
                                        text.createdTime = GetTime();
                                    }
                                    break;
                                }
                                default: 
                                {
                                    
                                }
                            }
                            if (fired) wp.triggered = true;
                            else        {
                                
                                return;   // block *everything* until they press
                            }
                        // }
                    }
                }
                // Apply Pop-in Animation
                if (character.pop_in && character.pop_in < 1.0f)
                {
                    float elapsedTime = GetTime() - text.createdTime - character.pop_in_delay.value_or(0.05f);
                    if (elapsedTime > 0)
                    {
                        character.pop_in = std::min(1.0f, elapsedTime / 0.5f);                  // 0.5s duration
                        character.pop_in = character.pop_in.value() * character.pop_in.value(); // Ease-in effect
                    }
                }

                // Apply all effects to the character
                for (const auto &[effectName, effectFunction] : character.effects)
                {
                    const auto &args = character.parsedEffectArguments.arguments.at(effectName);
                    // spdlog::debug("Applying effect: {} with arguments: {}", effectName, args.size());
                    effectFunction(dt, character, args);
                }

                // unset first frame flag
                character.firstFrame = false;

                // check if a character is the last one in the text, and there is an onFinishedAllEffects callback, and at least one effect is finished
                if (character.isFinalCharacterInText && text.onFinishedEffect && character.effectFinished.empty() == false)
                {
                    // run callback just once and clear
                    text.onFinishedEffect();
                    text.onFinishedEffect = nullptr;
                }
            }
        }

        std::string CodepointToString(int codepoint)
        {
            int utf8Size = 0;
            const char *utf8Char = CodepointToUTF8(codepoint, &utf8Size);

            if (utf8Size == 0 || utf8Char == nullptr)
            {
                // Return an empty string or handle invalid codepoint as needed
                spdlog::error("Invalid UTF-8 conversion for codepoint: {}", codepoint);
                return std::string();
            }

            // Construct a std::string from the UTF-8 character data
            return std::string(utf8Char, utf8Size);
        }
        
        //TODO: probably sync transform dimensions to this
        Vector2 calculateBoundingBox (entt::entity textEntity) {

            auto &text = globals::registry.get<Text>(textEntity);
            auto &transform = globals::registry.get<transform::Transform>(textEntity);

            // Calculate the bounding box dimensions
            float minX = std::numeric_limits<float>::max();
            float minY = std::numeric_limits<float>::max();
            float maxX = std::numeric_limits<float>::lowest();
            float maxY = std::numeric_limits<float>::lowest();

            // go through every character and get the highest offset, add the character's width to it
            for (auto &character: text.characters) {

                // get the character's position and size
                float charX = transform.getActualX() + character.offset.x * text.renderScale;
                float charY = transform.getActualY() +character.offset.y * text.renderScale;
                float charWidth = MeasureTextEx(text.fontData.font, CodepointToString(character.value).c_str(), text.fontSize, 1.0f).x * text.renderScale;
                float charHeight = MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y * text.renderScale; // Assuming height is same for all characters

                // Update min and max values
                minX = std::min(minX, charX);
                minY = std::min(minY, charY);
                maxX = std::max(maxX, charX + charWidth);
                maxY = std::max(maxY, charY + charHeight);
            }

            // auto &lastChar = text.characters.back();
            // // get line height of last character
            // float lineHeight = MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y;
            // maxY = transform.getActualY() + (lastChar.lineNumber + 1) * (lineHeight);

            float width = maxX - minX;
            float height = maxY - minY;

            // use transform scale to calculate the final width and height
            width *= transform.getVisualScaleWithHoverAndDynamicMotionReflected();
            height *= transform.getVisualScaleWithHoverAndDynamicMotionReflected();
            
            return {width, height};
        }

        void renderText(entt::entity textEntity, std::shared_ptr<layer::Layer> layerPtr, bool debug)
        {
            // ZoneScopedN("TextSystem::renderText");
            auto &text = globals::registry.get<Text>(textEntity);
            auto &textTransform = globals::registry.get<transform::Transform>(textEntity);
            float renderScale = text.renderScale; // 🟡 Use renderScale
            auto &layerOrder = globals::registry.get<layer::LayerOrderComponent>(textEntity);
            auto layerZIndex = layerOrder.zIndex;


            layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, layerZIndex);

            // Apply entity-level transforms
            layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = textTransform.getVisualX() + textTransform.getVisualW() * 0.5f, y = textTransform.getVisualY() + textTransform.getVisualH() * 0.5f](layer::CmdTranslate *cmd) {
                cmd->x = x;
                cmd->y = y;
            }, layerZIndex);
                
            if (text.applyTransformRotationAndScale)
            {
                layer::QueueCommand<layer::CmdScale>(layerPtr, [scaleX = textTransform.getVisualScaleWithHoverAndDynamicMotionReflected(), scaleY = textTransform.getVisualScaleWithHoverAndDynamicMotionReflected()](layer::CmdScale *cmd) {
                    cmd->scaleX = scaleX;
                    cmd->scaleY = scaleY;
                }, layerZIndex);

                layer::QueueCommand<layer::CmdRotate>(layerPtr, [rotation = textTransform.getVisualRWithDynamicMotionAndXLeaning()](layer::CmdRotate *cmd) {
                    cmd->angle = rotation;
                }, layerZIndex);
            }
            
            layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = -textTransform.getVisualW() * 0.5f, y = -textTransform.getVisualH() * 0.5f](layer::CmdTranslate *cmd) {
                cmd->x = x;
                cmd->y = y;
            }, layerZIndex);


            for (const auto &character : text.characters)
            {
                // ZoneScopedN("TextSystem::renderText-render single character");

                // if (character.isImage) 
                    // SPDLOG_DEBUG("Rendering image character: {} with size: {}x{}", character.value, character.size.x, character.size.y);
                

                float popInScale = 1.0f;
                if (character.pop_in)
                {
                    popInScale = character.pop_in.value();
                }

                // Calculate character position with offset
                Vector2 charPosition = {
                    character.offset.x * renderScale,
                    character.offset.y * renderScale};

                // add all optional offsets
                for (const auto &[effectName, offset] : character.offsets)
                {
                    charPosition.x += offset.x * renderScale;
                    charPosition.y += offset.y * renderScale;
                }
                
                int utf8Size = 0;
                static std::string utf8String;
                // Convert the codepoint to UTF-8 string for rendering
                {
                    // ZoneScopedN("TextSystem::renderText-codepoint to utf/string conversion");
                    
                    utf8String = CodepointToString(character.overrideCodepoint.value_or(character.value));
                }
                
                static Vector2 charSize = {0, 0};
                {
                    // ZoneScopedN("TextSystem::renderText-measure text size");
                    charSize = MeasureTextEx(text.fontData.font, utf8String.c_str(), text.fontSize, 1.0f);
                    charSize.x *= text.renderScale;
                    charSize.y *= text.renderScale;
                }
                

                if (character.isImage) { 
                    charSize.x = character.size.x * renderScale;
                    charSize.y = character.size.y * renderScale;
                }

                // sanity checkdd
                if (charSize.x == 0)
                {
                    const char* utf8Char = CodepointToUTF8(character.overrideCodepoint.value_or(character.value), &utf8Size);
                    spdlog::warn("Missing glyph for character: '{}'. Replacing with '?'.", utf8Char);
                    utf8Char = "?";
                }

                float finalScale = character.scale * popInScale;
                // apply additional scale modifiers
                for (const auto &[effectName, scaleModifier] : character.scaleModifiers)
                {
                    finalScale *= scaleModifier;
                }
                float finalScaleX = character.scaleXModifier.value_or(1.0f) * finalScale;
                float finalScaleY = character.scaleYModifier.value_or(1.0f) * finalScale;
                finalScaleX *= text.fontData.fontScale;
                finalScaleY *= text.fontData.fontScale;

                // add fontdata offset for finetuning
                if (!character.isImage) {
                    charPosition.x += text.fontData.fontRenderOffset.x * finalScaleX * renderScale;
                    charPosition.y += text.fontData.fontRenderOffset.y * finalScaleY * renderScale;
                }
                
                {
                    // ZoneScopedN("TextSystem::renderText-apply transformations");
                    layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, layerZIndex);

                    // apply scaling that is centered on the character
                    layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = charPosition.x + charSize.x * 0.5f, y = charPosition.y + charSize.y * 0.5f](layer::CmdTranslate *cmd) {
                        cmd->x = x;
                        cmd->y = y;
                    }, layerZIndex);
                    layer::QueueCommand<layer::CmdScale>(layerPtr, [scaleX = finalScaleX, scaleY = finalScaleY](layer::CmdScale *cmd) {
                        cmd->scaleX = scaleX;
                        cmd->scaleY = scaleY;
                    }, layerZIndex);
                    layer::QueueCommand<layer::CmdRotate>(layerPtr, [rotation = character.rotation](layer::CmdRotate *cmd) {
                        cmd->angle = rotation;
                    }, layerZIndex);
                    layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = -charSize.x * 0.5f, y = -charSize.y * 0.5f](layer::CmdTranslate *cmd) {
                        cmd->x = x;
                        cmd->y = y;
                    }, layerZIndex);
                }

                
                // render shadow if enabled
                // draw shadow based on shadow displacement
                if (text.shadow_enabled)
                {
                    // ZoneScopedN("TextSystem::renderText-render shadow");
                    float baseExaggeration = globals::BASE_SHADOW_EXAGGERATION;
                    float heightFactor = 1.0f + character.shadowHeight; // Increase effect based on height

                    float rawScale = text.renderScale;
                    float scaleFactor = std::clamp(rawScale * rawScale, 0.01f, 1.0f);

                    // Adjust for font size (reduce shadow effect when font size < 30)
                    float fontSize = static_cast<float>(text.fontData.fontLoadedSize);
                    float fontFactor = std::clamp(fontSize / 60.0f, 0.05f, 1.0f); // Tunable lower bound, higher denominator = less shadow

                    // Final combined scale factor
                    float finalFactor = scaleFactor * fontFactor;

                    float shadowOffsetX = character.shadowDisplacement.x * baseExaggeration * heightFactor * finalFactor;
                    float shadowOffsetY = -character.shadowDisplacement.y * baseExaggeration * heightFactor * finalFactor;

                    
                    // float shadowOffsetX = character.shadowDisplacement.x * baseExaggeration * heightFactor * renderScale;
                    // float shadowOffsetY = - character.shadowDisplacement.y * baseExaggeration * heightFactor * renderScale; // make shadow stretch downward
                    
                    // apply offsets to shadow if any
                    for (const auto &[effectName, offset] : character.shadowDisplacementOffsets)
                    {
                        shadowOffsetX += offset.x;
                        shadowOffsetY += offset.y;
                    }

                    // Translate to shadow position
                    layer::QueueCommand<layer::CmdTranslate>(layerPtr, [shadowOffsetX, shadowOffsetY](layer::CmdTranslate *cmd) {
                        cmd->x = -shadowOffsetX;
                        cmd->y = shadowOffsetY;
                    }, layerZIndex);

                    

                    if (character.isImage) {
                        // ZoneScopedN("TextSystem::renderText-render image shadow");
                        auto spriteFrame = init::getSpriteFrame(character.spriteUUID);
                        auto sourceRect = spriteFrame.frame;
                        auto atlasTexture = globals::textureAtlasMap[spriteFrame.atlasUUID];
                        auto destRect = Rectangle{0, 0, character.size.x, character.size.y};
                        
                        layer::QueueCommand<layer::CmdTexturePro>(layerPtr, [text, atlasTexture, sourceRect, destRect](layer::CmdTexturePro *cmd) {
                            cmd->texture = atlasTexture;
                            cmd->source = sourceRect;
                            cmd->offsetX = 0;
                            cmd->offsetY = 0;
                            cmd->size = {destRect.width, destRect.height};
                            cmd->rotationCenter = {0, 0};
                            cmd->rotation = 0;
                            cmd->color = Fade(BLACK, text.globalAlpha * 0.7f);
                        }, layerZIndex);
                        
                    }
                    else {
                        // ZoneScopedN("TextSystem::renderText-render text shadow");
                        // Draw shadow 
                        
                        layer::QueueCommand<layer::CmdTextPro>(layerPtr, [text, fontSize = text.fontSize, spacing = text.fontData.spacing, font = text.fontData.font, renderScale](layer::CmdTextPro *cmd) {
                            cmd->text = utf8String.c_str();
                            cmd->font = font;
                            cmd->x = 0;
                            cmd->y = 0;
                            cmd->origin = {0, 0};
                            cmd->rotation = 0;
                            cmd->fontSize = fontSize * renderScale;
                            cmd->spacing = spacing;
                            cmd->color = Fade(BLACK, text.globalAlpha * 0.7f);
                        }, layerZIndex);
                    }

                    // Reset translation to original position
                    layer::QueueCommand<layer::CmdTranslate>(layerPtr, [shadowOffsetX, shadowOffsetY](layer::CmdTranslate *cmd) {
                        cmd->x = shadowOffsetX;
                        cmd->y = -shadowOffsetY;
                    }, layerZIndex);
                }

                // Render the character
                if (character.isImage) {
                    // ZoneScopedN("TextSystem::renderText-render image");
                    auto spriteFrame = init::getSpriteFrame(character.spriteUUID);
                    auto sourceRect = spriteFrame.frame;
                    auto atlasTexture = globals::textureAtlasMap[spriteFrame.atlasUUID];
                    auto destRect = Rectangle{0, 0, character.size.x, character.size.y};
                    layer::QueueCommand<layer::CmdTexturePro>(layerPtr, [atlasTexture, sourceRect, destRect, fgTint = Color{.r = character.fgTint.r, .g = character.fgTint.g, .b = character.fgTint.b, .a = (unsigned char)(text.globalAlpha * character.fgTint.a) }](layer::CmdTexturePro *cmd) {
                        cmd->texture = atlasTexture;
                        cmd->source = sourceRect;
                        cmd->offsetX = 0;
                        cmd->offsetY = 0;
                        cmd->size = {destRect.width, destRect.height};
                        cmd->rotationCenter = {0, 0};
                        cmd->rotation = 0;
                        cmd->color = fgTint;
                    }, layerZIndex);
                }
                else {
                    // ZoneScopedN("TextSystem::renderText-render text");
                    layer::QueueCommand<layer::CmdTextPro>(layerPtr, [fontSize = text.fontSize, spacing = text.fontData.spacing, font = text.fontData.font, renderScale, color = Color{.r = character.color.r, .g = character.color.g, .b = character.color.b, .a = (unsigned char)(text.globalAlpha * character.color.a) }](layer::CmdTextPro *cmd) {
                        cmd->text = utf8String.c_str();
                        cmd->font = font;
                        cmd->x = 0;
                        cmd->y = 0;
                        cmd->origin = {0, 0};
                        cmd->rotation = 0;
                        cmd->fontSize = fontSize * renderScale;
                        cmd->spacing = spacing;
                        cmd->color = color;
                    }, layerZIndex);
                }
                
                if (debug && globals::drawDebugInfo) {
                    // ZoneScopedN("TextSystem::renderText-debug info");
                    // subtract finetuning offset
                    if (!character.isImage) {
                        layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = -text.fontData.fontRenderOffset.x * finalScaleX * renderScale, y = -text.fontData.fontRenderOffset.y * finalScaleY * renderScale](layer::CmdTranslate *cmd) {
                            cmd->x = x;
                            cmd->y = y;
                        }, layerZIndex);
                    }
                    
                    
                    // draw bounding box for the character
                    
                    layer::QueueCommand<layer::CmdDrawRectangleLinesPro>(layerPtr, [charSize = charSize](layer::CmdDrawRectangleLinesPro *cmd) {
                        cmd->offsetX = 0;
                        cmd->offsetY = 0;
                        cmd->size = charSize;
                        cmd->lineThickness = 1.0f;
                        cmd->color = BLUE;
                    }, layerZIndex);
                }
                
                layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, layerZIndex);
            }

            // Draw debug bounding box
            if (debug && globals::drawDebugInfo)
            {
                auto &transform = globals::registry.get<transform::Transform>(textEntity);
                
                // Calculate the bounding box dimensions
                auto [width, height] = calculateBoundingBox(textEntity);

                //FIXME: known bug where this bounding box stretchs to the right and down when scaled up, instead of being centered
                
                // Draw the bounding box for the text

                // Draw text showing the dimensions
                std::string dimensionsText = "Width: " + std::to_string(width) + ", Height: " + std::to_string(height);
                layer::QueueCommand<layer::CmdTextPro>(layerPtr, [dimensionsText = dimensionsText](layer::CmdTextPro *cmd) {
                    cmd->text = dimensionsText.c_str();
                    cmd->font = GetFontDefault();
                    cmd->x = 0;
                    cmd->y = -20;
                    cmd->origin = {0, 0};
                    cmd->rotation = 0;
                    cmd->fontSize = 10;
                    cmd->spacing = 0;
                    cmd->color = GRAY;
                }, layerZIndex);
            }
            
            layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, layerZIndex);
            
        }

        void clearAllEffects(entt::entity textEntity)
        {
            auto &text = globals::registry.get<Text>(textEntity);
            for (auto &character : text.characters)
            {

                character.effects.clear();
                character.parsedEffectArguments.arguments.clear();
                character.scaleModifiers.clear();
                character.offsets.clear();
                character.shadowDisplacementOffsets.clear();
                character.scaleXModifier.reset();
                character.scaleYModifier.reset();
                character.overrideCodepoint.reset();
                character.effectFinished.clear();
            }

        }

        void applyGlobalEffects(entt::entity textEntity, const std::string &effectString)
        {
            auto &text = globals::registry.get<Text>(textEntity);
            ParsedEffectArguments parsedArguments = splitEffects(effectString);

            for (auto &character : text.characters)
            {
                character.parsedEffectArguments.arguments.insert(parsedArguments.arguments.begin(), parsedArguments.arguments.end());

                for (const auto &[effectName, args] : parsedArguments.arguments)
                {
                    if (effectFunctions.count(effectName))
                    {
                        character.effects[effectName] = effectFunctions[effectName];
                    }
                    else
                    {
                        spdlog::warn("Effect '{}' not registered. Skipping.", effectName);
                    }
                }
            }
        }

        void debugPrintText(entt::entity textEntity)
        {
            auto &text = globals::registry.get<Text>(textEntity);
            SPDLOG_DEBUG("Text Entity: {}", static_cast<int>(textEntity));
            SPDLOG_DEBUG("\tText: {}", text.rawText);
            SPDLOG_DEBUG("\tFont: {}", text.fontData.font.baseSize);
            SPDLOG_DEBUG("\tFont Size: {}", text.fontSize);
            // SPDLOG_DEBUG("Position: ({}, {})", text.position.x, text.position.y);
            SPDLOG_DEBUG("\tAlignment: {}", magic_enum::enum_name<Text::Alignment>(text.alignment));
            SPDLOG_DEBUG("\tWrap Width: {}", text.wrapWidth);
            SPDLOG_DEBUG("\tWrap Mode: {}", static_cast<int>(text.wrapMode));
            SPDLOG_DEBUG("\tSpacing: {}", text.fontData.spacing);
            SPDLOG_DEBUG("\tShadow Enabled: {}", text.shadow_enabled);
            SPDLOG_DEBUG("\tPop-in Enabled: {}", text.pop_in_enabled);
            SPDLOG_DEBUG("\tCharacters: {}", text.characters.size());
            for (const auto &character : text.characters)
            {
                int byteCount = 0;
                SPDLOG_DEBUG("Character: '{}', Position (relative): ({}, {}), Line Number: {}, Effects: {}", CodepointToUTF8(character.value, &byteCount), character.offset.x, character.offset.y, character.lineNumber, character.effects.size());
                for (const auto &[effectName, effectFunction] : character.effects)
                {
                    SPDLOG_DEBUG("\t\tEffect: {}", effectName);
                }
            }
        }

    } // namespace Functions
} // namespace TextSystem

// // Example Usage
// int main() {
//     spdlog::set_level(spdlog::level::debug);
//     InitWindow(800, 600, "Text Effects System");
//     SetTargetFPS(60);

//     Font font = LoadFont("resources/arial.ttf");
//     TextSystem::Text text{
//         "Hello [World](color=red;x=4;y=4)", font, 20.0f, 400.0f, Vector2{100, 100}, 0};

//     TextSystem::Functions::initEffects(text);
//     TextSystem::Functions::parseText(text);

//     while (!WindowShouldClose()) {
//         BeginDrawing();
//         ClearBackground(RAYWHITE);

//         TextSystem::Functions::render(text, GetFrameTime());

//         EndDrawing();
//     }

//     UnloadFont(font);
//     CloseWindow();

//     return 0;
// }
