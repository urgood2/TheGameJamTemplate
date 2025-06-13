#pragma once

#include <string>
#include <vector>
#include <map>
#include <mutex>
#include <fstream>
#include <utility>
#include <sol/sol.hpp>
#include <spdlog/spdlog.h>

//-----------------------------------------------------------------------------
// BindingRecorder.hpp
// Generates Lua-definition (.lua_defs) files with rich documentation and versioning.
// Also provides helpers to bind & record in one call to reduce boilerplate.
//-----------------------------------------------------------------------------

struct MethodDef {
    std::string name;
    std::string signature;
    std::string doc;
    bool        is_static;
    bool        is_overload;
};

struct PropDef {
    std::string name;
    std::string value;
    std::string doc;
};

struct TypeDef {
    std::string name;
    std::string version;
    std::string doc;
    std::vector<std::string> base_classes;
    std::vector<MethodDef>   methods;
    std::vector<PropDef>     properties;
    bool is_data_class = false;
};

struct ModuleNode {
    std::map<std::string, ModuleNode> children;
    std::vector<MethodDef> functions;
};

class BindingRecorder {
public:
    static BindingRecorder& instance() {
        static BindingRecorder I;
        return I;
    }

    void set_module_version(const std::string& version) { module_version_ = version; }
    void set_module_doc    (const std::string& doc)     { module_doc_     = doc;     }
    void set_module_name   (const std::string& name)    { module_name_    = name;    }

    TypeDef& add_type(const std::string& name, bool is_data_class = false) {
        std::lock_guard<std::mutex> _(mtx_);
        types_.push_back(TypeDef{ name });
        TypeDef& new_type = types_.back();
        new_type.is_data_class = is_data_class;
        return new_type;
    }
    void record_method   (const std::string& type, MethodDef m) {
        std::lock_guard<std::mutex> _(mtx_);
        if (auto* t = find_type(type)) t->methods.emplace_back(std::move(m));
    }
    void record_property(const std::string& type, PropDef   p) {
        std::lock_guard<std::mutex> _(mtx_);
        if (auto* t = find_type(type)) t->properties.emplace_back(std::move(p));
    }
    void record_free_function(const std::vector<std::string>& path, MethodDef m) {
        std::lock_guard<std::mutex> _(mtx_);
        if (path.empty()) free_functions_.emplace_back(std::move(m));
        else ensure_module(path).functions.emplace_back(std::move(m));
    }

    template <typename Func>
    void bind_function(sol::state& lua,
                       const std::vector<std::string>& path,
                       const std::string& name,
                       Func&& f,
                       const std::string& signature,
                       const std::string& doc = "",
                       bool is_overload = false)
    {
        sol::table tbl = get_or_create_table(lua, path);
        tbl.set_function(name, std::forward<Func>(f));
        record_free_function(path, MethodDef{ name, signature, doc, true, is_overload });
    }

    template <typename T>
    void bind_usertype(sol::state& lua,
                       const std::string& name,
                       const std::string& version = "",
                       const std::string& doc = "",
                       const std::vector<std::string>& bases = {})
    {
        lua.new_usertype<T>(name);
        auto& td = add_type(name);
        td.version      = version;
        td.doc          = doc;
        td.base_classes = bases;
    }

    inline std::string join_path(const std::vector<std::string>& path, const std::string& name) {
        std::string out;
        for (auto& s : path) { if (!out.empty()) out += "."; out += s; }
        if (!out.empty()) out += ".";
        return out + name;
    }

    template <typename T, typename... Args>
    void bind_usertype(sol::state& lua,
                       const std::vector<std::string>& path,
                       const std::string& name,
                       const std::string& version = "",
                       const std::string& doc = "",
                       const std::vector<std::string>& bases = {},
                       Args&&... args)
    {
        sol::table tbl = get_or_create_table(lua, path);
        tbl.new_usertype<T>(name, std::forward<Args>(args)...);
        auto& td = add_type(join_path(path, name));
        td.version      = version;
        td.doc          = doc;
        td.base_classes = bases;
    }

    template <typename Func>
    void bind_method(sol::state& lua,
                     const std::string& type,
                     const std::string& name,
                     Func&& f,
                     const std::string& signature,
                     const std::string& doc = "",
                     bool is_static = false,
                     bool is_overload = false)
    {
        sol::table ut = lua[type];
        ut.set_function(name, std::forward<Func>(f));
        record_method(type, MethodDef{ name, signature, doc, is_static, is_overload });
    }

    void dump_lua_defs(const std::string& path) const {
        std::lock_guard<std::mutex> lock(mtx_);
        spdlog::info("dump_lua_defs: writing '{}'", path);

        std::ofstream out(path);
        if (!out.is_open()) { spdlog::error("failed to open '{}'", path); return; }

        out << "---@meta\n\n";
        out << "---\n--- " << module_doc_ << "\n---\n";
        out << "-- version: " << module_version_ << "\n";
        out << "---@class " << module_name_ << "\n\n";

        for (auto& m : free_functions_) {
            out << "---\n--- " << m.doc << "\n---\n";
            out << m.signature << "\n";
            out << "function " << m.name << "(...) end\n\n";
        }

        for (auto& t : types_) {
            out << "\n---\n--- " << t.doc << "\n---\n";
            out << "---@class " << t.name;
            if (!t.base_classes.empty()) {
                out << ":" << t.base_classes.front();
                for (size_t i = 1; i < t.base_classes.size(); ++i) out << "," << t.base_classes[i];
            }
            out << "\n";

            if (t.is_data_class) {
                // Emit as initialized table with nil fields + comments
                out << t.name << " = {\n";
                for (auto& prop : t.properties) {
                    out << "    " << prop.name << " = nil";
                    out << ", -- " << prop.value;
                    if (!prop.doc.empty()) out << " " << prop.doc;
                    out << "\n";
                }
                out << "}\n\n";
            } else {
                // Enums/constants
                out << t.name << " = {\n";
                for (size_t i = 0; i < t.properties.size(); ++i) {
                    auto& prop = t.properties[i];
                    out << "    " << prop.name << " = " << prop.value;
                    // ← add comma only if _not_ the last entry
                    if (i + 1 < t.properties.size()) out << ",";
                    if (!prop.doc.empty()) out << "  -- " << prop.doc;
                    out << "\n";
                }
                out << "}\n\n";
            }

            for (auto& m : t.methods) {
                out << "---\n--- " << m.doc << "\n---\n";
                if (m.is_overload) out << "---@overload fun" << m.signature << "\n";
                else out << m.signature << "\n";
                out << "function " << t.name
                    << (m.is_static ? "." : ":") << m.name << "(...) end\n\n";
            }
        }

        for (auto& [modname, node] : modules_) dump_module(out, {modname}, node);
        out.close();
        spdlog::info("finished '{}'", path);
    }

private:
    BindingRecorder() = default;
    mutable std::mutex mtx_;

    std::string module_name_{"<unnamed>"}, module_version_{"0.0"}, module_doc_{""};
    std::vector<TypeDef> types_;
    std::vector<MethodDef> free_functions_;
    std::map<std::string, ModuleNode> modules_;

    TypeDef* find_type(const std::string& name) {
        for (auto& t : types_) if (t.name == name) return &t;
        return nullptr;
    }

    sol::table get_or_create_table(sol::state& lua,
                                   const std::vector<std::string>& path) {
        sol::table tbl = lua.globals();
        for (auto& p : path) {
            sol::object child = tbl[p];
            if (child.get_type() != sol::type::table) {
                sol::table new_tbl = lua.create_table();
                tbl[p] = new_tbl;
                tbl = new_tbl;
            } else tbl = child.as<sol::table>();
        }
        return tbl;
    }

    ModuleNode& ensure_module(const std::vector<std::string>& path) {
        if (path.empty()) throw std::invalid_argument("path empty");
        ModuleNode* cur = &modules_[path[0]];
        for (size_t i = 1; i < path.size(); ++i) cur = &cur->children[path[i]];
        return *cur;
    }

    void dump_module(std::ofstream& out,
                     std::vector<std::string> path,
                     const ModuleNode& node) const
    {
        std::string full = path[0];
        for (size_t i = 1; i < path.size(); ++i) full += "." + path[i];
        for (auto& m : node.functions) {
            out << "---\n--- " << m.doc << "\n---\n";
            out << m.signature << "\n";
            out << "function " << full << "." << m.name << "(...) end\n\n";
        }
        for (auto& [nm, child] : node.children) {
            auto sub = path;
            sub.push_back(nm);
            dump_module(out, sub, child);
        }
    }
};



/*

---@meta
Marks the file as an “EmmyLua metadata” file so the language server treats it as pure definitions (no runtime code).

---@class <Name>[:<Base>]
Declares a type or namespace.

    Without bases, it creates a new table-­like class.

    With :Base1,Base2 it indicates inheritance (so IDEs know members of the base(s) also apply).

---@overload fun(…):<Ret>
Describes an alternative function signature (i.e. an overloaded version) that doesn’t get a real function stub. The IDE will know there’s another way to call it, what parameters and return types to expect.

---@param <name> <type> [# <comment>]
Documents one function argument:

    <name> is the parameter’s name

    <type> its Lua type (or union, optional via ?)

    The # comment is an inline description for IDE tooltips.

---@return <type> [<name> # <comment>]
Documents a return value:

    <type> is what’s returned (can be union like A|string)

    Optionally you give it a name and # comment to describe what it means.

---@vararg <type>
Signals that the function accepts additional (variadic) arguments of the given type beyond those explicitly named.

---@alias <Name> <definition>
Defines a custom type alias (e.g. enumerations or callback‐signature types). After this, you can use <Name> wherever a type is expected.

*/


/*

Binding styles:



        // publishLuaEventNoArgs
        rec.bind_function(
            lua,
            {},
            "publishLuaEventNoArgs",
            [](const std::string& eventType) {
                sol::table data = sol::lua_nil;
                publishLuaEvent(eventType, data);
            },
            "---@param eventType string # The Lua event name\n"
            "---@return nil",
            "Publishes a Lua-defined event with no arguments."
        );

        // resetListenersForLuaEvent
        rec.bind_function(
            lua,
            {},
            "resetListenersForLuaEvent",
            &resetListenersForLuaEvent,
            "---@param eventType string # The Lua event name\n"
            "---@return nil",
            "Clears all listeners for the specified Lua-defined event."
        );


        
        // 1) Module‐level banner
        auto& rec = BindingRecorder::instance();
        rec.set_module_name("chugget.engine");
        rec.set_module_version("0.1");
        rec.set_module_doc("Bindings for chugget's c++ code, for use with lua.");
        
        //---------------------------------------------------------
        // initialize lua state with custom object bindings
        //---------------------------------------------------------
        stateToInit.new_enum("ActionResult",
            "SUCCESS", Action::Result::SUCCESS,
            "FAILURE", Action::Result::FAILURE,
            "RUNNING", Action::Result::RUNNING
        );
        // 3) Record it as a class with constant fields
        //    (so dump_lua_defs will emit @class + @field for each value)
        rec.add_type("ActionResult").doc = "Results of an action";
        rec.record_property("ActionResult", { "SUCCESS", "0", "When succeeded" });
        rec.record_property("ActionResult", { "FAILURE", "1", "When failed" });
        rec.record_property("ActionResult", { "RUNNING", "2", "When still running" });
        
        // stateToInit.new_usertype<entt::entity>("Entity");
        // 3) Bind & record the Entity usertype
        rec.bind_usertype<entt::entity>(
            stateToInit,
            "Entity",
            "0.1",
            "Wraps an EnTT entity handle for Lua scripts."
        );
    } 

    // types with properties
    // Vector3
    {
        auto& vec3 = rec.add_type("random_utils.Vector3");
        vec3.doc = "3D vector with x, y, and z coordinates.";
        rec.record_property("random_utils.Vector3", { "x", "number", "X coordinate" });
        rec.record_property("random_utils.Vector3", { "y", "number", "Y coordinate" });
        rec.record_property("random_utils.Vector3", { "z", "number", "Z coordinate" });
    }



    // --------------- for enums within tables:

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

*/