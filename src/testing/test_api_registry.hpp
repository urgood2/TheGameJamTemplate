#pragma once

#include <filesystem>
#include <map>
#include <optional>
#include <string>
#include <vector>

#include "testing/test_mode_config.hpp"

namespace testing {

struct ArgumentDef {
    std::string name;
    std::string type;
    bool required = true;
    std::string description;
};

struct StatePathDef {
    std::string path;
    std::string type;
    bool writable = false;
    std::string description;
};

struct QueryDef {
    std::string name;
    std::vector<ArgumentDef> arguments;
    std::string returns;
    std::string description;
};

struct CommandDef {
    std::string name;
    std::vector<ArgumentDef> arguments;
    std::string description;
};

class TestApiRegistry {
public:
    void initialize(const TestModeConfig& config);

    void set_version(const std::string& version);
    std::string get_version() const;

    void register_state_path(const StatePathDef& def);
    std::optional<StatePathDef> get_state_path(const std::string& path) const;
    std::vector<StatePathDef> get_all_state_paths() const;

    void register_query(const QueryDef& def);
    std::optional<QueryDef> get_query(const std::string& name) const;
    std::vector<QueryDef> get_all_queries() const;

    void register_command(const CommandDef& def);
    std::optional<CommandDef> get_command(const std::string& name) const;
    std::vector<CommandDef> get_all_commands() const;

    void register_capability(const std::string& name, bool available);
    bool has_capability(const std::string& name) const;
    std::map<std::string, bool> get_all_capabilities() const;

    bool validate_state_path(const std::string& path) const;
    bool validate_query(const std::string& name) const;
    bool validate_command(const std::string& name) const;

    std::string compute_fingerprint() const;
    bool write_json(const std::filesystem::path& path) const;

private:
    static bool is_valid_semver(const std::string& version);

    std::string version_ = "0.0.0";
    std::map<std::string, StatePathDef> state_paths_;
    std::map<std::string, QueryDef> queries_;
    std::map<std::string, CommandDef> commands_;
    std::map<std::string, bool> capabilities_;
};

} // namespace testing
