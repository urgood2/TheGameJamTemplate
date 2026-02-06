#include "testing/lua_state_query.hpp"

#include <cctype>
#include <string>
#include <vector>

namespace testing {

namespace {

struct PathSegment {
    enum class Kind { Key, Index };
    Kind kind = Kind::Key;
    std::string key;
    int index = 0;
};

std::string segment_label(const PathSegment& segment) {
    if (segment.kind == PathSegment::Kind::Key) {
        return segment.key;
    }
    return "[" + std::to_string(segment.index) + "]";
}

bool parse_identifier(const std::string& path, size_t& i, std::string& out) {
    if (i >= path.size()) {
        return false;
    }
    const char first = path[i];
    if (!std::isalpha(static_cast<unsigned char>(first)) && first != '_') {
        return false;
    }
    size_t start = i;
    ++i;
    while (i < path.size()) {
        const char ch = path[i];
        if (!std::isalnum(static_cast<unsigned char>(ch)) && ch != '_') {
            break;
        }
        ++i;
    }
    out = path.substr(start, i - start);
    return !out.empty();
}

bool parse_bracket(const std::string& path, size_t& i, PathSegment& out) {
    if (i >= path.size() || path[i] != '[') {
        return false;
    }
    ++i;
    if (i >= path.size()) {
        return false;
    }
    char ch = path[i];
    if (ch == '"' || ch == '\'') {
        const char quote = ch;
        ++i;
        std::string key;
        while (i < path.size()) {
            char current = path[i];
            if (current == '\\' && i + 1 < path.size()) {
                char next = path[i + 1];
                if (next == quote || next == '\\') {
                    key.push_back(next);
                    i += 2;
                    continue;
                }
            }
            if (current == quote) {
                break;
            }
            key.push_back(current);
            ++i;
        }
        if (i >= path.size() || path[i] != quote) {
            return false;
        }
        ++i;
        if (i >= path.size() || path[i] != ']') {
            return false;
        }
        ++i;
        out.kind = PathSegment::Kind::Key;
        out.key = key;
        return true;
    }

    if (!std::isdigit(static_cast<unsigned char>(ch))) {
        return false;
    }
    size_t start = i;
    while (i < path.size() && std::isdigit(static_cast<unsigned char>(path[i]))) {
        ++i;
    }
    if (start == i) {
        return false;
    }
    if (i >= path.size() || path[i] != ']') {
        return false;
    }
    const std::string digits = path.substr(start, i - start);
    ++i;
    out.kind = PathSegment::Kind::Index;
    out.index = std::stoi(digits);
    return true;
}

bool parse_path(const std::string& path, std::vector<PathSegment>& out, std::string& error) {
    out.clear();
    if (path.empty()) {
        error = "invalid_path:" + path;
        return false;
    }
    size_t i = 0;
    bool expect_segment = true;
    while (i < path.size()) {
        char ch = path[i];
        if (ch == '.') {
            if (expect_segment) {
                error = "invalid_path:" + path;
                return false;
            }
            ++i;
            expect_segment = true;
            continue;
        }

        if (ch == '[') {
            PathSegment segment;
            if (!parse_bracket(path, i, segment)) {
                error = "invalid_path:" + path;
                return false;
            }
            out.push_back(segment);
            expect_segment = false;
            continue;
        }

        std::string key;
        if (!parse_identifier(path, i, key)) {
            error = "invalid_path:" + path;
            return false;
        }
        PathSegment segment;
        segment.kind = PathSegment::Kind::Key;
        segment.key = key;
        out.push_back(segment);
        expect_segment = false;
    }
    if (expect_segment) {
        error = "invalid_path:" + path;
        return false;
    }
    return true;
}

LuaValue make_error(lua_State* L, std::string& last_error, const std::string& message) {
    last_error = message;
    LuaValue out;
    if (L != nullptr) {
        sol::state_view lua(L);
        out.value = sol::make_object(lua, sol::lua_nil);
    }
    out.error = message;
    return out;
}

bool resolve_path(sol::state_view lua,
                  const std::vector<PathSegment>& segments,
                  sol::object& out,
                  std::string& error) {
    sol::object current = sol::make_object(lua, lua.globals());
    for (size_t i = 0; i < segments.size(); ++i) {
        const auto& segment = segments[i];
        if (current.get_type() != sol::type::table) {
            error = "type_error:expected_table_at:" + segment_label(segment);
            return false;
        }
        sol::table table = current;
        sol::object next;
        if (segment.kind == PathSegment::Kind::Key) {
            next = table[segment.key];
        } else {
            const int lua_index = segment.index + 1;
            next = table[lua_index];
        }
        if (next == sol::lua_nil && i + 1 < segments.size()) {
            error = "type_error:missing_segment:" + segment_label(segment);
            return false;
        }
        current = next;
    }
    out = current;
    return true;
}

bool resolve_parent(sol::state_view lua,
                    const std::vector<PathSegment>& segments,
                    sol::table& parent,
                    PathSegment& last,
                    std::string& error) {
    if (segments.empty()) {
        error = "invalid_path:";
        return false;
    }
    if (segments.size() == 1) {
        parent = lua.globals();
        last = segments.back();
        return true;
    }
    sol::object current = sol::make_object(lua, lua.globals());
    for (size_t i = 0; i + 1 < segments.size(); ++i) {
        const auto& segment = segments[i];
        if (current.get_type() != sol::type::table) {
            error = "type_error:expected_table_at:" + segment_label(segment);
            return false;
        }
        sol::table table = current;
        sol::object next;
        if (segment.kind == PathSegment::Kind::Key) {
            next = table[segment.key];
        } else {
            const int lua_index = segment.index + 1;
            next = table[lua_index];
        }
        if (next == sol::lua_nil) {
            error = "type_error:missing_segment:" + segment_label(segment);
            return false;
        }
        current = next;
    }
    if (current.get_type() != sol::type::table) {
        error = "type_error:expected_table_at:" + segment_label(segments[segments.size() - 2]);
        return false;
    }
    parent = current.as<sol::table>();
    last = segments.back();
    return true;
}

bool prepare_call_args(const std::vector<LuaValue>& args,
                       std::vector<sol::object>& out,
                       std::string& error) {
    out.clear();
    out.reserve(args.size());
    for (const auto& arg : args) {
        if (!arg.ok()) {
            error = "type_error:argument_error";
            return false;
        }
        out.push_back(arg.value);
    }
    return true;
}

} // namespace

void LuaStateQuery::initialize(TestApiRegistry& registry, lua_State* L) {
    registry_ = &registry;
    lua_ = L;
    last_error_.clear();
}

LuaValue LuaStateQuery::get_state(const std::string& path) {
    if (registry_ == nullptr || lua_ == nullptr) {
        return make_error(lua_, last_error_, "type_error:uninitialized");
    }
    if (!registry_->validate_state_path(path)) {
        return make_error(lua_, last_error_, "capability_missing:" + path);
    }
    std::vector<PathSegment> segments;
    std::string error;
    if (!parse_path(path, segments, error)) {
        return make_error(lua_, last_error_, error);
    }
    sol::state_view lua(lua_);
    sol::object value;
    if (!resolve_path(lua, segments, value, error)) {
        return make_error(lua_, last_error_, error);
    }
    LuaValue result;
    result.value = value;
    return result;
}

bool LuaStateQuery::set_state(const std::string& path, const LuaValue& value) {
    if (registry_ == nullptr || lua_ == nullptr) {
        last_error_ = "type_error:uninitialized";
        return false;
    }
    auto def = registry_->get_state_path(path);
    if (!def.has_value()) {
        last_error_ = "capability_missing:" + path;
        return false;
    }
    if (!def->writable) {
        last_error_ = "read_only:" + path;
        return false;
    }
    std::vector<PathSegment> segments;
    std::string error;
    if (!parse_path(path, segments, error)) {
        last_error_ = error;
        return false;
    }
    sol::state_view lua(lua_);
    sol::table parent;
    PathSegment last;
    if (!resolve_parent(lua, segments, parent, last, error)) {
        last_error_ = error;
        return false;
    }
    if (!value.ok()) {
        last_error_ = "type_error:argument_error";
        return false;
    }
    sol::object payload = value.value;
    if (!payload.valid()) {
        payload = sol::make_object(lua, sol::lua_nil);
    }
    if (last.kind == PathSegment::Kind::Key) {
        parent[last.key] = payload;
    } else {
        const int lua_index = last.index + 1;
        parent[lua_index] = payload;
    }
    last_error_.clear();
    return true;
}

LuaValue LuaStateQuery::execute_query(const std::string& name, const std::vector<LuaValue>& args) {
    if (registry_ == nullptr || lua_ == nullptr) {
        return make_error(lua_, last_error_, "type_error:uninitialized");
    }
    if (!registry_->validate_query(name)) {
        return make_error(lua_, last_error_, "capability_missing:" + name);
    }
    std::vector<PathSegment> segments;
    std::string error;
    if (!parse_path(name, segments, error)) {
        return make_error(lua_, last_error_, error);
    }
    sol::state_view lua(lua_);
    sol::object target;
    if (!resolve_path(lua, segments, target, error)) {
        return make_error(lua_, last_error_, error);
    }
    if (target.get_type() != sol::type::function) {
        return make_error(lua_, last_error_, "type_error:not_function:" + name);
    }
    std::vector<sol::object> call_args;
    if (!prepare_call_args(args, call_args, error)) {
        return make_error(lua_, last_error_, error);
    }
    sol::protected_function fn = target;
    sol::protected_function_result result = fn(sol::as_args(call_args));
    if (!result.valid()) {
        sol::error err = result;
        return make_error(lua_, last_error_, "type_error:query_failed:" + std::string(err.what()));
    }
    sol::object out = result.get<sol::object>();
    LuaValue value;
    value.value = out;
    return value;
}

bool LuaStateQuery::execute_command(const std::string& name, const std::vector<LuaValue>& args) {
    if (registry_ == nullptr || lua_ == nullptr) {
        last_error_ = "type_error:uninitialized";
        return false;
    }
    if (!registry_->validate_command(name)) {
        last_error_ = "capability_missing:" + name;
        return false;
    }
    std::vector<PathSegment> segments;
    std::string error;
    if (!parse_path(name, segments, error)) {
        last_error_ = error;
        return false;
    }
    sol::state_view lua(lua_);
    sol::object target;
    if (!resolve_path(lua, segments, target, error)) {
        last_error_ = error;
        return false;
    }
    if (target.get_type() != sol::type::function) {
        last_error_ = "type_error:not_function:" + name;
        return false;
    }
    std::vector<sol::object> call_args;
    if (!prepare_call_args(args, call_args, error)) {
        last_error_ = error;
        return false;
    }
    sol::protected_function fn = target;
    sol::protected_function_result result = fn(sol::as_args(call_args));
    if (!result.valid()) {
        sol::error err = result;
        last_error_ = "type_error:command_failed:" + std::string(err.what());
        return false;
    }
    sol::object out = result.get<sol::object>();
    if (out.is<bool>()) {
        last_error_.clear();
        return out.as<bool>();
    }
    if (out == sol::lua_nil) {
        last_error_.clear();
        return true;
    }
    last_error_.clear();
    return true;
}

const std::string& LuaStateQuery::last_error() const {
    return last_error_;
}

void LuaStateQuery::clear() {
    registry_ = nullptr;
    lua_ = nullptr;
    last_error_.clear();
}

} // namespace testing
