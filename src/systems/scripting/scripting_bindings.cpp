// Scripting-specific Lua bindings
// Contains bindings for logging, entity aliases, and other scripting utilities

#include "scripting_functions.hpp"
#include "binding_recorder.hpp"
#include "sol/sol.hpp"
#include "spdlog/spdlog.h"
#include <sstream>

namespace scripting {

void exposeScriptingUtilities(sol::state& lua) {
  auto& rec = BindingRecorder::instance();

  // ------------------------------------------------------
  // Entity alias functions
  // ------------------------------------------------------
  lua.set_function("getEntityByAlias", getEntityByAlias);
  lua.set_function("setEntityAlias", setEntityAlias);
  rec.record_free_function(
      {}, {"getEntityByAlias", "---@param alias string\n---@return Entity|nil",
           "Retrieves an entity by its string alias.", true, false});
  rec.record_free_function(
      {}, {"setEntityAlias",
           "---@param alias string\n---@param entity Entity\n---@return nil",
           "Assigns a string alias to an entity.", true, false});

  // ------------------------------------------------------
  // Logging functions
  // ------------------------------------------------------
  lua.set_function(
      "log_debug", [](sol::this_state ts, sol::variadic_args va) {
        // Validate: at least one argument required
        if (va.size() == 0) {
          SPDLOG_WARN("[log_debug] Called with no arguments - nothing to log");
          return;
        }

        sol::state_view L{ts};
        std::ostringstream oss;

        // Check if first arg is an entity
        auto it = va.begin();
        bool hasEntity = false;
        entt::entity e = entt::null;
        if (it != va.end() && it->get_type() == sol::type::number) {
          // Sol2 represents entt::entity as integer
          e = static_cast<entt::entity>(it->as<int>());
          hasEntity = true;
          ++it;
        }

        // Validate: if entity was provided, need at least one more arg for message
        if (hasEntity && it == va.end()) {
          SPDLOG_WARN("[log_debug] Entity provided but no message - nothing to log");
          return;
        }

        // Concatenate the rest
        bool first = true;
        for (; it != va.end(); ++it) {
          if (!first)
            oss << ' ';
          first = false;

          // Convert any Lua value to string via tostring()
          sol::object obj = *it;
          sol::function tostr = L["tostring"];
          std::string s = tostr(obj);
          oss << s;
        }

        // Dispatch to the correct backend
        if (hasEntity) {
          luaDebugLogWrapper(e, oss.str());
        } else {
          luaDebugLogWrapperNoEntity(oss.str());
        }
      });

  // Main signature
  rec.record_free_function(
      {}, {"log_debug",
           "---@param entity Entity # The entity to associate the log with.\n"
           "---@param message string # The message to log. Can be variadic "
           "arguments.\n"
           "---@return nil",
           "Logs a debug message associated with an entity.", true, false});
  // Overload for no entity
  rec.record_free_function({}, {"log_debug",
                                "---@overload fun(message: string):nil",
                                "Logs a general debug message.", true, true});

  lua.set_function(
      "log_error", [](sol::this_state ts, sol::variadic_args va) {
        // Validate: at least one argument required
        if (va.size() == 0) {
          SPDLOG_WARN("[log_error] Called with no arguments - nothing to log");
          return;
        }

        sol::state_view L{ts};
        std::ostringstream oss;

        // Check if first arg is an entity
        auto it = va.begin();
        bool hasEntity = false;
        entt::entity e = entt::null;
        if (it != va.end() && it->get_type() == sol::type::number) {
          // Sol2 represents entt::entity as integer
          e = static_cast<entt::entity>(it->as<int>());
          hasEntity = true;
          ++it;
        }

        // Validate: if entity was provided, need at least one more arg for message
        if (hasEntity && it == va.end()) {
          SPDLOG_WARN("[log_error] Entity provided but no message - nothing to log");
          return;
        }

        // Concatenate the rest
        bool first = true;
        for (; it != va.end(); ++it) {
          if (!first)
            oss << ' ';
          first = false;

          // Convert any Lua value to string via tostring()
          sol::object obj = *it;
          sol::function tostr = L["tostring"];
          std::string s = tostr(obj);
          oss << s;
        }

        // Dispatch to the correct backend
        if (hasEntity) {
          luaErrorLogWrapper(e, oss.str());
        } else {
          luaErrorLogWrapperNoEntity(oss.str());
        }
      });

  // Main signature
  rec.record_free_function(
      {}, {"log_error",
           "---@param entity Entity # The entity to associate the error with.\n"
           "---@param message string # The error message. Can be variadic "
           "arguments.\n"
           "---@return nil",
           "Logs an error message associated with an entity.", true, false});
  // Overload for no entity
  rec.record_free_function({}, {"log_error",
                                "---@overload fun(message: string):nil",
                                "Logs a general error message.", true, true});

  // log_info with tag support
  lua.set_function(
      "log_info", [](sol::this_state ts, sol::variadic_args va) {
        if (va.size() == 0) {
          SPDLOG_WARN("[log_info] Called with no arguments");
          return;
        }

        auto it = va.begin();
        std::string tag = "general";

        // Check if first arg is a string tag (not entity)
        if (it->is<std::string>() && va.size() >= 2) {
          // Could be tag + message, or just messages
          std::string first = it->as<std::string>();
          // Simple heuristic: short lowercase = tag
          if (first.size() <= 20 && std::all_of(first.begin(), first.end(),
              [](char c) { return std::islower(c) || c == '_'; })) {
            tag = first;
            ++it;
          }
        }

        std::ostringstream oss;
        for (; it != va.end(); ++it) {
          if (it->is<std::string>()) {
            oss << it->as<std::string>();
          } else if (it->is<int>()) {
            oss << it->as<int>();
          } else if (it->is<double>()) {
            oss << it->as<double>();
          } else if (it->is<bool>()) {
            oss << (it->as<bool>() ? "true" : "false");
          } else {
            oss << "[?]";
          }
          oss << " ";
        }

        spdlog::info("[{}] {}", tag, oss.str());
      });

  rec.record_free_function(
      {}, {"log_info",
           "---@param tag string # System tag (e.g., 'physics', 'combat')\n"
           "---@param ... any # Message parts to log",
           "Logs an info message with system tag.", true, false});
  rec.record_free_function(
      {}, {"log_info",
           "---@overload fun(message: string):nil",
           "Logs a general info message.", true, true});

  // log_warn with tag support
  lua.set_function(
      "log_warn", [](sol::this_state ts, sol::variadic_args va) {
        if (va.size() == 0) {
          SPDLOG_WARN("[log_warn] Called with no arguments");
          return;
        }

        auto it = va.begin();
        std::string tag = "general";

        if (it->is<std::string>() && va.size() >= 2) {
          std::string first = it->as<std::string>();
          if (first.size() <= 20 && std::all_of(first.begin(), first.end(),
              [](char c) { return std::islower(c) || c == '_'; })) {
            tag = first;
            ++it;
          }
        }

        std::ostringstream oss;
        for (; it != va.end(); ++it) {
          if (it->is<std::string>()) {
            oss << it->as<std::string>();
          } else if (it->is<int>()) {
            oss << it->as<int>();
          } else if (it->is<double>()) {
            oss << it->as<double>();
          } else if (it->is<bool>()) {
            oss << (it->as<bool>() ? "true" : "false");
          } else {
            oss << "[?]";
          }
          oss << " ";
        }

        spdlog::warn("[{}] {}", tag, oss.str());
      });

  rec.record_free_function(
      {}, {"log_warn",
           "---@param tag string # System tag\n"
           "---@param ... any # Message parts",
           "Logs a warning with system tag.", true, false});
  rec.record_free_function(
      {}, {"log_warn",
           "---@overload fun(message: string):nil",
           "Logs a general warning.", true, true});

  // ------------------------------------------------------
  // Game state (pause/unpause)
  // ------------------------------------------------------
  lua.set_function("pauseGame", pauseGame);
  lua.set_function("unpauseGame", unpauseGame);
  rec.record_free_function(
      {}, {"pauseGame", "---@return nil", "Pauses the game.", true, false});
  rec.record_free_function(
      {}, {"unpauseGame", "---@return nil", "Unpauses the game.", true, false});

  // ------------------------------------------------------
  // Input helper (isKeyPressed)
  // ------------------------------------------------------
  lua.set_function("isKeyPressed", isKeyPressed);
  rec.record_free_function(
      {},
      {"isKeyPressed", "---@param key string\n---@return boolean",
       "Checks if a specific keyboard key is currently pressed.", true, false});
}

} // namespace scripting
