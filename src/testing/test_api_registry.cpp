#include "testing/test_api_registry.hpp"

#include <algorithm>
#include <algorithm>
#include <cctype>
#include <fstream>
#include <iomanip>
#include <sstream>

#include "nlohmann/json.hpp"

namespace testing {

namespace {

constexpr const char* kSchemaVersion = "1.0.0";

std::string bool_token(bool value) {
    return value ? "1" : "0";
}

std::string normalize_description(const std::string& value) {
    std::string out;
    out.reserve(value.size());
    for (char ch : value) {
        if (ch == '\n' || ch == '\r' || ch == '\t') {
            out.push_back(' ');
        } else {
            out.push_back(ch);
        }
    }
    return out;
}

} // namespace

void TestApiRegistry::initialize(const TestModeConfig& config) {
    (void)config;
    version_ = "0.0.0";
    state_paths_.clear();
    queries_.clear();
    commands_.clear();
    capabilities_.clear();
}

void TestApiRegistry::set_version(const std::string& version) {
    if (!is_valid_semver(version)) {
        return;
    }
    version_ = version;
}

std::string TestApiRegistry::get_version() const {
    return version_;
}

void TestApiRegistry::register_state_path(const StatePathDef& def) {
    state_paths_[def.path] = def;
}

std::optional<StatePathDef> TestApiRegistry::get_state_path(const std::string& path) const {
    auto it = state_paths_.find(path);
    if (it == state_paths_.end()) {
        return std::nullopt;
    }
    return it->second;
}

std::vector<StatePathDef> TestApiRegistry::get_all_state_paths() const {
    std::vector<StatePathDef> result;
    result.reserve(state_paths_.size());
    for (const auto& pair : state_paths_) {
        result.push_back(pair.second);
    }
    return result;
}

void TestApiRegistry::register_query(const QueryDef& def) {
    queries_[def.name] = def;
}

std::optional<QueryDef> TestApiRegistry::get_query(const std::string& name) const {
    auto it = queries_.find(name);
    if (it == queries_.end()) {
        return std::nullopt;
    }
    return it->second;
}

std::vector<QueryDef> TestApiRegistry::get_all_queries() const {
    std::vector<QueryDef> result;
    result.reserve(queries_.size());
    for (const auto& pair : queries_) {
        result.push_back(pair.second);
    }
    return result;
}

void TestApiRegistry::register_command(const CommandDef& def) {
    commands_[def.name] = def;
}

std::optional<CommandDef> TestApiRegistry::get_command(const std::string& name) const {
    auto it = commands_.find(name);
    if (it == commands_.end()) {
        return std::nullopt;
    }
    return it->second;
}

std::vector<CommandDef> TestApiRegistry::get_all_commands() const {
    std::vector<CommandDef> result;
    result.reserve(commands_.size());
    for (const auto& pair : commands_) {
        result.push_back(pair.second);
    }
    return result;
}

void TestApiRegistry::register_capability(const std::string& name, bool available) {
    capabilities_[name] = available;
}

bool TestApiRegistry::has_capability(const std::string& name) const {
    auto it = capabilities_.find(name);
    if (it == capabilities_.end()) {
        return false;
    }
    return it->second;
}

std::map<std::string, bool> TestApiRegistry::get_all_capabilities() const {
    return capabilities_;
}

bool TestApiRegistry::validate_state_path(const std::string& path) const {
    return state_paths_.find(path) != state_paths_.end();
}

bool TestApiRegistry::validate_query(const std::string& name) const {
    return queries_.find(name) != queries_.end();
}

bool TestApiRegistry::validate_command(const std::string& name) const {
    return commands_.find(name) != commands_.end();
}

std::string TestApiRegistry::compute_fingerprint() const {
    std::string payload;
    auto append_line = [&](const std::string& value) {
        payload.append(value);
        payload.push_back('\n');
    };

    append_line("schema_version=" + std::string(kSchemaVersion));
    append_line("version=" + version_);
    for (const auto& pair : state_paths_) {
        const auto& def = pair.second;
        append_line("state|" + def.path + "|" + def.type + "|" + bool_token(def.writable) + "|" +
                    normalize_description(def.description));
    }
    for (const auto& pair : queries_) {
        const auto& def = pair.second;
        std::string args;
        for (const auto& arg : def.arguments) {
            if (!args.empty()) {
                args.push_back(';');
            }
            args.append(arg.name);
            args.push_back(':');
            args.append(arg.type);
            args.push_back(':');
            args.append(bool_token(arg.required));
            args.push_back(':');
            args.append(normalize_description(arg.description));
        }
        append_line("query|" + def.name + "|" + def.returns + "|" + normalize_description(def.description) + "|" + args);
    }
    for (const auto& pair : commands_) {
        const auto& def = pair.second;
        std::string args;
        for (const auto& arg : def.arguments) {
            if (!args.empty()) {
                args.push_back(';');
            }
            args.append(arg.name);
            args.push_back(':');
            args.append(arg.type);
            args.push_back(':');
            args.append(bool_token(arg.required));
            args.push_back(':');
            args.append(normalize_description(arg.description));
        }
        append_line("cmd|" + def.name + "|" + normalize_description(def.description) + "|" + args);
    }
    for (const auto& pair : capabilities_) {
        append_line("cap|" + pair.first + "|" + bool_token(pair.second));
    }

    constexpr std::uint64_t kOffset = 14695981039346656037ull;
    constexpr std::uint64_t kPrime = 1099511628211ull;
    std::uint64_t hash = kOffset;
    for (unsigned char ch : payload) {
        hash ^= ch;
        hash *= kPrime;
    }

    std::ostringstream oss;
    oss << "fnv64:" << std::hex << std::setw(16) << std::setfill('0') << hash;
    return oss.str();
}

bool TestApiRegistry::write_json(const std::filesystem::path& path) const {
    using json = nlohmann::json;
    json root = json::object();
    root["schema_version"] = kSchemaVersion;
    root["version"] = version_;

    auto state_paths = json::array();
    for (const auto& pair : state_paths_) {
        const auto& def = pair.second;
        state_paths.push_back(json{
            {"path", def.path},
            {"type", def.type},
            {"writable", def.writable},
            {"description", def.description},
        });
    }
    root["state_paths"] = state_paths;

    auto queries = json::array();
    for (const auto& pair : queries_) {
        const auto& def = pair.second;
        json args = json::array();
        for (const auto& arg : def.arguments) {
            args.push_back(json{
                {"name", arg.name},
                {"type", arg.type},
                {"required", arg.required},
                {"description", arg.description},
            });
        }
        queries.push_back(json{
            {"name", def.name},
            {"arguments", args},
            {"returns", def.returns},
            {"description", def.description},
        });
    }
    root["queries"] = queries;

    auto commands = json::array();
    for (const auto& pair : commands_) {
        const auto& def = pair.second;
        json args = json::array();
        for (const auto& arg : def.arguments) {
            args.push_back(json{
                {"name", arg.name},
                {"type", arg.type},
                {"required", arg.required},
                {"description", arg.description},
            });
        }
        commands.push_back(json{
            {"name", def.name},
            {"arguments", args},
            {"description", def.description},
        });
    }
    root["commands"] = commands;

    json caps = json::object();
    for (const auto& pair : capabilities_) {
        caps[pair.first] = pair.second;
    }
    root["capabilities"] = caps;

    std::filesystem::path parent = path.parent_path();
    if (!parent.empty()) {
        std::error_code ec;
        std::filesystem::create_directories(parent, ec);
    }

    std::ofstream out(path);
    if (!out) {
        return false;
    }
    out << root.dump(2);
    return static_cast<bool>(out);
}

bool TestApiRegistry::is_valid_semver(const std::string& version) {
    if (version.empty()) {
        return false;
    }
    int sections = 0;
    std::string token;
    for (char ch : version) {
        if (ch == '.') {
            if (token.empty()) {
                return false;
            }
            if (!std::all_of(token.begin(), token.end(), [](unsigned char c) { return std::isdigit(c); })) {
                return false;
            }
            ++sections;
            token.clear();
            continue;
        }
        token.push_back(ch);
    }
    if (token.empty()) {
        return false;
    }
    if (!std::all_of(token.begin(), token.end(), [](unsigned char c) { return std::isdigit(c); })) {
        return false;
    }
    ++sections;
    return sections == 3;
}

} // namespace testing
