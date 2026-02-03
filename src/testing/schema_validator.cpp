#include "testing/schema_validator.hpp"

#include <cstdlib>
#include <fstream>
#include <regex>
#include <sstream>

#include <spdlog/spdlog.h>

namespace testing {
namespace {

std::filesystem::path resolve_schema_path(const std::filesystem::path& path) {
    if (std::filesystem::exists(path)) {
        return path;
    }
    auto cursor = std::filesystem::current_path();
    for (int i = 0; i < 4; ++i) {
        auto candidate = cursor / path;
        if (std::filesystem::exists(candidate)) {
            return candidate;
        }
        if (!cursor.has_parent_path()) {
            break;
        }
        cursor = cursor.parent_path();
    }
    return path;
}

std::string type_label(const nlohmann::json& value) {
    if (value.is_null()) {
        return "null";
    }
    if (value.is_boolean()) {
        return "boolean";
    }
    if (value.is_number_integer()) {
        return "integer";
    }
    if (value.is_number()) {
        return "number";
    }
    if (value.is_string()) {
        return "string";
    }
    if (value.is_array()) {
        return "array";
    }
    if (value.is_object()) {
        return "object";
    }
    return "unknown";
}

bool matches_type(const nlohmann::json& value, const std::string& type) {
    if (type == "null") {
        return value.is_null();
    }
    if (type == "boolean") {
        return value.is_boolean();
    }
    if (type == "integer") {
        return value.is_number_integer();
    }
    if (type == "number") {
        return value.is_number();
    }
    if (type == "string") {
        return value.is_string();
    }
    if (type == "array") {
        return value.is_array();
    }
    if (type == "object") {
        return value.is_object();
    }
    return false;
}

bool matches_type_spec(const nlohmann::json& value, const nlohmann::json& type_spec) {
    if (type_spec.is_string()) {
        return matches_type(value, type_spec.get<std::string>());
    }
    if (type_spec.is_array()) {
        for (const auto& type_entry : type_spec) {
            if (type_entry.is_string() && matches_type(value, type_entry.get<std::string>())) {
                return true;
            }
        }
    }
    return false;
}

const nlohmann::json* resolve_ref(const nlohmann::json& root,
                                  const std::string& ref,
                                  std::string& err) {
    if (ref.rfind("#/", 0) != 0) {
        err = "unsupported $ref: " + ref;
        return nullptr;
    }
    try {
        nlohmann::json::json_pointer pointer(ref.substr(1));
        return &root.at(pointer);
    } catch (const std::exception& ex) {
        err = std::string("failed to resolve $ref: ") + ref + " (" + ex.what() + ")";
        return nullptr;
    }
}

bool validate_value(const nlohmann::json& instance,
                    const nlohmann::json& schema,
                    const nlohmann::json& root,
                    std::string& err,
                    const std::string& path) {
    if (schema.contains("$ref")) {
        std::string ref_err;
        const auto* resolved = resolve_ref(root, schema["$ref"].get<std::string>(), ref_err);
        if (!resolved) {
            err = path + " " + ref_err;
            return false;
        }
        return validate_value(instance, *resolved, root, err, path);
    }

    if (schema.contains("anyOf")) {
        std::string last_err;
        for (const auto& option : schema["anyOf"]) {
            std::string option_err;
            if (validate_value(instance, option, root, option_err, path)) {
                return true;
            }
            last_err = option_err;
        }
        err = last_err.empty() ? (path + " failed anyOf validation") : last_err;
        return false;
    }

    if (schema.contains("type")) {
        if (!matches_type_spec(instance, schema["type"])) {
            err = path + " expected type " + schema["type"].dump() + " but got " + type_label(instance);
            return false;
        }
    }

    if (schema.contains("enum")) {
        bool matched = false;
        for (const auto& option : schema["enum"]) {
            if (option == instance) {
                matched = true;
                break;
            }
        }
        if (!matched) {
            err = path + " value not in enum";
            return false;
        }
    }

    if (schema.contains("pattern") && instance.is_string()) {
        try {
            const std::regex pattern(schema["pattern"].get<std::string>());
            if (!std::regex_match(instance.get<std::string>(), pattern)) {
                err = path + " string does not match pattern";
                return false;
            }
        } catch (const std::exception& ex) {
            err = path + " invalid pattern: " + std::string(ex.what());
            return false;
        }
    }

    if (schema.contains("minimum") && instance.is_number()) {
        const double min_value = schema["minimum"].get<double>();
        if (instance.get<double>() < min_value) {
            err = path + " value below minimum";
            return false;
        }
    }

    if (instance.is_object()) {
        if (schema.contains("required")) {
            for (const auto& key : schema["required"]) {
                const auto& key_str = key.get<std::string>();
                if (!instance.contains(key_str)) {
                    err = path + " missing required property " + key_str;
                    return false;
                }
            }
        }

        const bool has_properties = schema.contains("properties") && schema["properties"].is_object();
        const bool has_additional = schema.contains("additionalProperties");
        for (auto it = instance.begin(); it != instance.end(); ++it) {
            const std::string key = it.key();
            const auto& value = it.value();
            const std::string next_path = path.empty() ? key : path + "." + key;
            if (has_properties && schema["properties"].contains(key)) {
                if (!validate_value(value, schema["properties"][key], root, err, next_path)) {
                    return false;
                }
                continue;
            }

            if (has_additional) {
                const auto& additional = schema["additionalProperties"];
                if (additional.is_boolean()) {
                    if (!additional.get<bool>()) {
                        err = next_path + " additional property not allowed";
                        return false;
                    }
                } else if (additional.is_object()) {
                    if (!validate_value(value, additional, root, err, next_path)) {
                        return false;
                    }
                }
            }
        }
    }

    if (instance.is_array()) {
        if (schema.contains("items") && schema["items"].is_object()) {
            const auto& item_schema = schema["items"];
            for (size_t idx = 0; idx < instance.size(); ++idx) {
                std::string next_path = path + "[" + std::to_string(idx) + "]";
                if (!validate_value(instance[idx], item_schema, root, err, next_path)) {
                    return false;
                }
            }
        }
    }

    return true;
}

} // namespace

SchemaValidationResult validate_json_against_schema(const nlohmann::json& instance,
                                                   const nlohmann::json& schema) {
    SchemaValidationResult result;
    std::string err;
    result.ok = validate_value(instance, schema, schema, err, "");
    if (!result.ok) {
        result.error = err.empty() ? "schema validation failed" : err;
    }
    return result;
}

SchemaValidationResult validate_json_with_schema_file(const nlohmann::json& instance,
                                                     const std::filesystem::path& schema_path) {
    SchemaValidationResult result;
    nlohmann::json schema;
    std::string err;
    if (!load_json_file(schema_path, schema, err)) {
        result.ok = false;
        result.error = err;
        return result;
    }
    return validate_json_against_schema(instance, schema);
}

bool load_json_file(const std::filesystem::path& path,
                   nlohmann::json& out,
                   std::string& err) {
    const auto resolved = resolve_schema_path(path);
    std::ifstream file(resolved);
    if (!file) {
        err = "unable to open json file: " + resolved.string();
        return false;
    }
    try {
        file >> out;
        return true;
    } catch (const std::exception& ex) {
        err = std::string("failed to parse json file: ") + resolved.string() + " (" + ex.what() + ")";
        return false;
    }
}

bool write_json_file(const std::filesystem::path& path,
                    const nlohmann::json& value,
                    std::string& err) {
    std::error_code ec;
    std::filesystem::path resolved = path;
    if (!resolved.empty() && resolved.has_parent_path()) {
        std::filesystem::create_directories(resolved.parent_path(), ec);
        if (ec) {
            err = "failed to create directory: " + resolved.parent_path().string();
            return false;
        }
    }
    std::ofstream out(resolved);
    if (!out) {
        err = "unable to write json file: " + resolved.string();
        return false;
    }
    out << value.dump(2);
    return true;
}

void validate_or_exit(const std::filesystem::path& schema_path,
                      const nlohmann::json& instance,
                      const std::string& label) {
    const auto result = validate_json_with_schema_file(instance, schema_path);
    if (result.ok) {
        return;
    }
    SPDLOG_ERROR("[test_mode] schema validation failed for {}: {}", label, result.error);
    std::exit(2);
}

} // namespace testing
