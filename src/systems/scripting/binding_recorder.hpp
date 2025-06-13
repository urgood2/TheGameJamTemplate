#pragma once

#include <string>
#include <vector>
#include <map>
#include <mutex>
#include <fstream>
#include <utility>
#include <sol/sol.hpp>            // for sol::state and sol::table
#include <spdlog/spdlog.h>        // for logging

//-----------------------------------------------------------------------------
// BindingRecorder.hpp
// Generates Lua-definition (.lua_defs) files with rich documentation and versioning.
// Also provides helpers to bind & record in one call to reduce boilerplate.
//-----------------------------------------------------------------------------

struct MethodDef {
    std::string name;
    std::string signature;     // e.g. "---@return number x # description"
    std::string doc;           // free-form description text
    bool        is_static;
    bool        is_overload;    // if part of @overload annotation
};

struct PropDef {
    std::string name;
    std::string value;         // literal value, e.g. "0", "1", or "\"foo\""
    std::string doc;           // optional comment
};

struct TypeDef {
    std::string name;
    std::string version;       // e.g. "11.5"
    std::string doc;
    std::vector<std::string> base_classes;
    std::vector<MethodDef>    methods;
    std::vector<PropDef>      properties;
};

// Tree node for nested modules/tables
struct ModuleNode {
    std::map<std::string, ModuleNode> children;
    std::vector<MethodDef>    functions;
};

class BindingRecorder {
public:
    static BindingRecorder& instance() {
        static BindingRecorder I;
        return I;
    }

    //--- Module-level metadata
    void set_module_version(const std::string& version) { module_version_ = version; }
    void set_module_doc(const std::string& doc)         { module_doc_ = doc; }
    void set_module_name(const std::string& name)       { module_name_ = name; }

    //--- Direct record APIs
    TypeDef& add_type(const std::string& name) {
        std::lock_guard<std::mutex> _(mtx_);
        types_.push_back(TypeDef{ name });
        return types_.back();
    }
    void record_method(const std::string& type, MethodDef m) {
        std::lock_guard<std::mutex> _(mtx_);
        if (auto* t = find_type(type)) t->methods.push_back(std::move(m));
    }
    void record_property(const std::string& type, PropDef p) {
        std::lock_guard<std::mutex> _(mtx_);
        if (auto* t = find_type(type)) t->properties.push_back(std::move(p));
    }
    void record_free_function(const std::vector<std::string>& path, MethodDef m) {
        std::lock_guard<std::mutex> _(mtx_);
        ensure_module(path).functions.push_back(std::move(m));
    }

    //--- Combined bind & record helpers

    // Bind a free function into a nested table (or global) and record it
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
        record_free_function(path, MethodDef{name, signature, doc, /*is_static=*/true, is_overload});
    }

    // Bind a usertype and record the stub
    template <typename T>
    void bind_usertype(sol::state& lua,
                       const std::string& name,
                       const std::string& version = "",
                       const std::string& doc = "",
                       const std::vector<std::string>& bases = {})
    {
        lua.new_usertype<T>(name);
        auto& td = add_type(name);
        td.version = version;
        td.doc = doc;
        td.base_classes = bases;
    }

    // Bind a method on a usertype and record it
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
        record_method(type, MethodDef{name, signature, doc, is_static, is_overload});
    }

    //--- Emit .lua_defs
    void dump_lua_defs(const std::string& path) const {
        std::lock_guard<std::mutex> lock(mtx_);
        spdlog::info("dump_lua_defs: triggered, writing {}", path);

        std::ofstream out(path);
        if (!out.is_open()) {
            spdlog::error("dump_lua_defs: failed to open output file '{}'", path);
            return;
        }

        // header
        out << "---@meta\n\n";
        out << "---\n";
        out << "--- " << module_doc_ << "\n";
        out << "---\n";
        out << "-- version: " << module_version_ << "\n";
        out << "---@class " << module_name_ << "\n";

        // Emit each type with its real-value properties
        for (auto& t : types_) {
            out << "\n";
            out << "---\n";
            out << "--- " << t.doc << "\n";
            out << "---\n";
            out << "---@class " << t.name;
            if (!t.base_classes.empty()) {
                out << ":" << t.base_classes.front();
                for (size_t i = 1; i < t.base_classes.size(); ++i)
                    out << "," << t.base_classes[i];
            }
            out << "\n";

            // Emit a real Lua table literal containing the constants
            out << "local " << t.name << " = {\n";
            for (auto& prop : t.properties) {
                out << "    " << prop.name
                    << " = " << prop.value;
                if (!prop.doc.empty()) out << "  -- " << prop.doc;
                out << "\n";
            }
            out << "}\n\n";

            // Now emit any recorded methods
            for (auto& m : t.methods) {
                out << "---\n";
                out << "--- " << m.doc << "\n";
                out << "---\n";
                if (m.is_overload)
                    out << "---@overload fun" << m.signature << "\n";
                else
                    out << m.signature << "\n";
                out << "function " << t.name
                    << (m.is_static ? "." : ":")
                    << m.name << "(...) end\n\n";
            }
        }

        // Emit any free functions under modules_
        for (auto& [name, node] : modules_) {
            dump_module(out, { name }, node);
        }

        out.close();
        spdlog::info("dump_lua_defs: finished writing {}", path);
    }

private:
    BindingRecorder() = default;
    mutable std::mutex mtx_;

    std::string module_name_{""}, module_version_{"0.0"}, module_doc_{""};
    std::vector<TypeDef> types_;
    std::map<std::string, ModuleNode> modules_;

    TypeDef* find_type(const std::string& name) {
        for (auto& t : types_)
            if (t.name == name) return &t;
        return nullptr;
    }

    sol::table get_or_create_table(sol::state& lua, const std::vector<std::string>& path) {
        sol::table tbl = lua.globals();
        for (auto& p : path) {
            if (!tbl[p]) tbl[p] = lua.create_table();
            tbl = tbl[p];
        }
        return tbl;
    }

    ModuleNode& ensure_module(const std::vector<std::string>& path) {
        ModuleNode* cur = &modules_[path[0]];
        for (size_t i = 1; i < path.size(); ++i)
            cur = &cur->children[path[i]];
        return *cur;
    }

    void dump_module(std::ofstream& out,
                     const std::vector<std::string>& path,
                     const ModuleNode& node) const
    {
        std::string full = path[0];
        for (size_t i = 1; i < path.size(); ++i)
            full += "." + path[i];

        for (auto& m : node.functions) {
            out << "---\n";
            out << "--- " << m.doc << "\n";
            out << "---\n";
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