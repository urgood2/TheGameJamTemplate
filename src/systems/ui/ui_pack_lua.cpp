#include "sol/sol.hpp"
#include "ui_pack.hpp"
#include "ui_data.hpp"
#include "systems/scripting/binding_recorder.hpp"
#include <spdlog/spdlog.h>

namespace ui {

namespace {

/// Helper struct representing a UI pack "handle" from Lua's perspective
struct PackHandle {
    std::string packName;

    explicit PackHandle(std::string name) : packName(std::move(name)) {}
};

/// Convert a RegionDef to a UIConfig for rendering
UIConfig makeConfigFromRegion(const RegionDef& region, Texture2D* atlas) {
    UIConfig config;

    if (region.ninePatch.has_value()) {
        // 9-patch rendering
        config.stylingType = UIStylingType::NINEPATCH_BORDERS;
        config.nPatchInfo = region.ninePatch.value();
        if (atlas) {
            config.nPatchSourceTexture = *atlas;
        }
    } else {
        // Sprite rendering
        config.stylingType = UIStylingType::SPRITE;
        config.spriteSourceTexture = atlas;
        config.spriteSourceRect = region.region;
        config.spriteScaleMode = region.scaleMode;
    }

    return config;
}

} // anonymous namespace

void exposePackToLua(::sol::state& lua) {
    auto& rec = BindingRecorder::instance();

    // Get or create the 'ui' table
    ::sol::table ui = lua["ui"].get_or_create<::sol::table>();

    //=========================================================
    // SpriteScaleMode enum
    //=========================================================
    lua.new_enum<SpriteScaleMode>("SpriteScaleMode", {
        {"Stretch", SpriteScaleMode::Stretch},
        {"Tile", SpriteScaleMode::Tile},
        {"Fixed", SpriteScaleMode::Fixed}
    });

    auto& scaleModeEnum = rec.add_type("SpriteScaleMode");
    scaleModeEnum.doc = "Defines how sprites are scaled when rendered in UI elements.";
    rec.record_property("SpriteScaleMode", {"Stretch", "0", "Scale sprite to fit container."});
    rec.record_property("SpriteScaleMode", {"Tile", "1", "Repeat sprite to fill area."});
    rec.record_property("SpriteScaleMode", {"Fixed", "2", "Draw at original size, centered."});

    //=========================================================
    // PackHandle usertype
    //=========================================================
    lua.new_usertype<PackHandle>("PackHandle",
        sol::constructors<>(),

        // panel(name) -> UIConfig
        "panel", [&lua](PackHandle& handle, const std::string& name) -> sol::object {
            auto* pack = getPack(handle.packName);
            if (!pack) {
                SPDLOG_WARN("UI pack '{}' not found", handle.packName);
                return sol::lua_nil;
            }

            auto it = pack->panels.find(name);
            if (it == pack->panels.end()) {
                SPDLOG_WARN("Panel '{}' not found in pack '{}'", name, handle.packName);
                return sol::lua_nil;
            }

            UIConfig config = makeConfigFromRegion(it->second, pack->atlas);
            return sol::make_object(lua, config);
        },

        // button(name, state?) -> UIConfig
        "button", [&lua](PackHandle& handle, const std::string& name,
                     sol::optional<std::string> state) -> sol::object {
            auto* pack = getPack(handle.packName);
            if (!pack) {
                SPDLOG_WARN("UI pack '{}' not found", handle.packName);
                return sol::lua_nil;
            }

            auto it = pack->buttons.find(name);
            if (it == pack->buttons.end()) {
                SPDLOG_WARN("Button '{}' not found in pack '{}'", name, handle.packName);
                return sol::lua_nil;
            }

            const ButtonDef& btn = it->second;
            const RegionDef* region = &btn.normal;

            // Select state variant
            if (state.has_value()) {
                const std::string& s = state.value();
                if (s == "hover" && btn.hover.has_value()) {
                    region = &btn.hover.value();
                } else if (s == "pressed" && btn.pressed.has_value()) {
                    region = &btn.pressed.value();
                } else if (s == "disabled" && btn.disabled.has_value()) {
                    region = &btn.disabled.value();
                }
            }

            UIConfig config = makeConfigFromRegion(*region, pack->atlas);
            return sol::make_object(lua, config);
        },

        // progress_bar(name, part) -> UIConfig
        "progress_bar", [&lua](PackHandle& handle, const std::string& name,
                          const std::string& part) -> sol::object {
            auto* pack = getPack(handle.packName);
            if (!pack) {
                SPDLOG_WARN("UI pack '{}' not found", handle.packName);
                return sol::lua_nil;
            }

            auto it = pack->progressBars.find(name);
            if (it == pack->progressBars.end()) {
                SPDLOG_WARN("ProgressBar '{}' not found in pack '{}'", name, handle.packName);
                return sol::lua_nil;
            }

            const ProgressBarDef& bar = it->second;
            const RegionDef* region = nullptr;

            if (part == "background") {
                region = &bar.background;
            } else if (part == "fill") {
                region = &bar.fill;
            } else {
                SPDLOG_WARN("Invalid progress bar part '{}' (use 'background' or 'fill')", part);
                return sol::lua_nil;
            }

            UIConfig config = makeConfigFromRegion(*region, pack->atlas);
            return sol::make_object(lua, config);
        },

        // scrollbar(name, part) -> UIConfig
        "scrollbar", [&lua](PackHandle& handle, const std::string& name,
                       const std::string& part) -> sol::object {
            auto* pack = getPack(handle.packName);
            if (!pack) {
                SPDLOG_WARN("UI pack '{}' not found", handle.packName);
                return sol::lua_nil;
            }

            auto it = pack->scrollbars.find(name);
            if (it == pack->scrollbars.end()) {
                SPDLOG_WARN("Scrollbar '{}' not found in pack '{}'", name, handle.packName);
                return sol::lua_nil;
            }

            const ScrollbarDef& sb = it->second;
            const RegionDef* region = nullptr;

            if (part == "track") {
                region = &sb.track;
            } else if (part == "thumb") {
                region = &sb.thumb;
            } else {
                SPDLOG_WARN("Invalid scrollbar part '{}' (use 'track' or 'thumb')", part);
                return sol::lua_nil;
            }

            UIConfig config = makeConfigFromRegion(*region, pack->atlas);
            return sol::make_object(lua, config);
        },

        // slider(name, part) -> UIConfig
        "slider", [&lua](PackHandle& handle, const std::string& name,
                    const std::string& part) -> sol::object {
            auto* pack = getPack(handle.packName);
            if (!pack) {
                SPDLOG_WARN("UI pack '{}' not found", handle.packName);
                return sol::lua_nil;
            }

            auto it = pack->sliders.find(name);
            if (it == pack->sliders.end()) {
                SPDLOG_WARN("Slider '{}' not found in pack '{}'", name, handle.packName);
                return sol::lua_nil;
            }

            const SliderDef& slider = it->second;
            const RegionDef* region = nullptr;

            if (part == "track") {
                region = &slider.track;
            } else if (part == "thumb") {
                region = &slider.thumb;
            } else {
                SPDLOG_WARN("Invalid slider part '{}' (use 'track' or 'thumb')", part);
                return sol::lua_nil;
            }

            UIConfig config = makeConfigFromRegion(*region, pack->atlas);
            return sol::make_object(lua, config);
        },

        // input(name, state?) -> UIConfig
        "input", [&lua](PackHandle& handle, const std::string& name,
                   sol::optional<std::string> state) -> sol::object {
            auto* pack = getPack(handle.packName);
            if (!pack) {
                SPDLOG_WARN("UI pack '{}' not found", handle.packName);
                return sol::lua_nil;
            }

            auto it = pack->inputs.find(name);
            if (it == pack->inputs.end()) {
                SPDLOG_WARN("Input '{}' not found in pack '{}'", name, handle.packName);
                return sol::lua_nil;
            }

            const InputDef& input = it->second;
            const RegionDef* region = &input.normal;

            if (state.has_value() && state.value() == "focus" && input.focus.has_value()) {
                region = &input.focus.value();
            }

            UIConfig config = makeConfigFromRegion(*region, pack->atlas);
            return sol::make_object(lua, config);
        },

        // icon(name) -> UIConfig
        "icon", [&lua](PackHandle& handle, const std::string& name) -> sol::object {
            auto* pack = getPack(handle.packName);
            if (!pack) {
                SPDLOG_WARN("UI pack '{}' not found", handle.packName);
                return sol::lua_nil;
            }

            auto it = pack->icons.find(name);
            if (it == pack->icons.end()) {
                SPDLOG_WARN("Icon '{}' not found in pack '{}'", name, handle.packName);
                return sol::lua_nil;
            }

            UIConfig config = makeConfigFromRegion(it->second, pack->atlas);
            return sol::make_object(lua, config);
        }
    );

    auto& packHandleType = rec.add_type("PackHandle");
    packHandleType.doc = "Handle to a registered UI asset pack for accessing themed UI elements.";

    rec.record_method("PackHandle", {
        "panel",
        "---@param name string # Name of the panel\n"
        "---@return UIConfig|nil",
        "Gets configuration for a panel element from this pack.",
        false, false
    });

    rec.record_method("PackHandle", {
        "button",
        "---@param name string # Name of the button\n"
        "---@param state? string # State: 'normal', 'hover', 'pressed', 'disabled'\n"
        "---@return UIConfig|nil",
        "Gets configuration for a button element in a specific state.",
        false, false
    });

    rec.record_method("PackHandle", {
        "progress_bar",
        "---@param name string # Name of the progress bar\n"
        "---@param part string # Part: 'background' or 'fill'\n"
        "---@return UIConfig|nil",
        "Gets configuration for a progress bar component.",
        false, false
    });

    rec.record_method("PackHandle", {
        "scrollbar",
        "---@param name string # Name of the scrollbar\n"
        "---@param part string # Part: 'track' or 'thumb'\n"
        "---@return UIConfig|nil",
        "Gets configuration for a scrollbar component.",
        false, false
    });

    rec.record_method("PackHandle", {
        "slider",
        "---@param name string # Name of the slider\n"
        "---@param part string # Part: 'track' or 'thumb'\n"
        "---@return UIConfig|nil",
        "Gets configuration for a slider component.",
        false, false
    });

    rec.record_method("PackHandle", {
        "input",
        "---@param name string # Name of the input field\n"
        "---@param state? string # State: 'normal' or 'focus'\n"
        "---@return UIConfig|nil",
        "Gets configuration for an input field in a specific state.",
        false, false
    });

    rec.record_method("PackHandle", {
        "icon",
        "---@param name string # Name of the icon\n"
        "---@return UIConfig|nil",
        "Gets configuration for an icon element.",
        false, false
    });

    //=========================================================
    // Global ui.register_pack and ui.use_pack
    //=========================================================

    ui.set_function("register_pack", [](const std::string& name, const std::string& manifestPath) -> bool {
        return registerPack(name, manifestPath);
    });

    rec.record_free_function({"ui"}, {
        "register_pack",
        "---@param name string # Unique name for the pack\n"
        "---@param manifestPath string # Path to the JSON manifest file\n"
        "---@return boolean # True if registration succeeded",
        "Registers a UI asset pack from a JSON manifest file.",
        true, false
    });

    ui.set_function("use_pack", [&lua](const std::string& name) -> sol::object {
        auto* pack = getPack(name);
        if (!pack) {
            SPDLOG_WARN("UI pack '{}' not found", name);
            return sol::lua_nil;
        }
        return sol::make_object(lua, PackHandle{name});
    });

    rec.record_free_function({"ui"}, {
        "use_pack",
        "---@param name string # Name of the registered pack\n"
        "---@return PackHandle|nil # Handle to the pack, or nil if not found",
        "Gets a handle to a registered UI asset pack.",
        true, false
    });

    SPDLOG_INFO("Exposed UI pack system to Lua");
}

} // namespace ui
