
#pragma once

#include <map>
#include <string>
#include <fstream>
#include <nlohmann/json.hpp>

#include "util/common_headers.hpp"
#include "third_party/unify/unify.hpp"

namespace uuid {
    extern std::map<std::string, std::string> map;

    // Add a file to the disk mapping. Returns the UID of the file
    inline std::string add(const std::string &uri) {
        map[unify(uri)] = uri;
        return unify(uri);
    }

    // Lookup the physical path representation using UID or URI
    inline std::string lookup(const std::string &uid_or_uri) {
        const auto unified = unify(uid_or_uri);

        if (auto it = map.find(unified); it != map.end()) {
            return it->second;
        }

        // Fallback: if `unify` is not idempotent for this key (e.g. "keyboard_s"
        // losing its trailing 's'), try the raw identifier as well.
        if (auto it = map.find(uid_or_uri); it != map.end()) {
            return it->second;
        }

        return {};
    }

    
    /*
        Enhanced function to dump the current map to JSON, while:
         - Reading in the existing file (if present).
         - Validating old entries by calling `uuid::add(...)` on each stored path
           and checking if it yields the same UID (key).
         - Keeping only valid entries (removing invalid).
         - Merging new items from the current map into this JSON structure.
         - Storing multiple valid paths per UID in an array.
    */
    inline void dump_to_json(const std::string& filepath) {
        nlohmann::json oldJson;

        // 1. Read the existing file if it exists
        {
            std::ifstream inFile(filepath);
            if (inFile.is_open()) {
                try {
                    SPDLOG_DEBUG("Reading existing JSON file: '{}'", filepath);
                    inFile >> oldJson;
                }
                catch (const std::exception& e) {
                    SPDLOG_ERROR("Failed to parse JSON file '{}': {}", filepath, e.what());
                }
                inFile.close();
            } else {
                SPDLOG_DEBUG("No existing JSON file found at '{}', starting fresh.", filepath);
            }
        }

        // 2. Convert any single string values to arrays (for consistent processing later).
        //    Also remove any non-string/non-array fields.
        std::vector<std::string> keysToRemove;
        for (auto& [uid, value] : oldJson.items()) {
            if (value.is_string()) {
                // Convert a single string to a one-element array
                auto singleValue = value.get<std::string>();
                // SPDLOG_DEBUG("Converting key '{}' with single value '{}' to array.", uid, singleValue);

                nlohmann::json arr = nlohmann::json::array();
                arr.push_back(singleValue);
                oldJson[uid] = arr;
            }
            else if (value.is_array()) {
                // SPDLOG_DEBUG("Key '{}' already has an array value. No conversion needed.", uid);
            }
            else {
                // SPDLOG_DEBUG("Key '{}' has an invalid type (not string or array). Marking for removal.", uid);
                keysToRemove.push_back(uid);
            }
        }

        // Remove invalid keys
        for (auto& k : keysToRemove) {
            SPDLOG_DEBUG("Removing invalid key '{}'.", k);
            oldJson.erase(k);
        }
        keysToRemove.clear();

        // 3. Verify the array entries. If unify(entry) != uid, remove that entry from the array.
        //    If the array becomes empty, remove the UID entirely.
        for (auto it = oldJson.begin(); it != oldJson.end(); /* no increment here */) {
            const std::string& uid = it.key();
            auto& arr = it.value(); // Guaranteed to be an array now

            // Filter invalid elements
            nlohmann::json newArr = nlohmann::json::array();
            for (auto& item : arr) {
                if (!item.is_string()) {
                    SPDLOG_DEBUG("Encountered non-string element for UID '{}', ignoring.", uid);
                    continue;
                }

                std::string potentialPath = item.get<std::string>();
                if (unify(potentialPath) == uid) {
                    // SPDLOG_DEBUG("UID '{}' is valid with path '{}'. Keeping.", uid, potentialPath);
                    newArr.push_back(potentialPath);
                } else {
                    SPDLOG_DEBUG(
                        "Removing invalid path '{}' for UID '{}' (unify(...) does not match).",
                        potentialPath, uid
                    );
                }
            }

            if (newArr.empty()) {
                // SPDLOG_DEBUG("UID '{}' has no valid paths left. Removing from JSON.", uid);
                it = oldJson.erase(it);
            } else {
                // Replace the old array with the new filtered array
                oldJson[uid] = newArr;
                ++it;
            }
        }

        // 4. Merge the current in-memory map with the validated oldJson data
        //    For each entry in our in-memory map:
        //      - Only add if unify(value) == key (ensuring it’s valid).
        //      - Append the path to the array if not already present.
        for (const auto& [uid, path] : uuid::map) {
            // Validate
            if (unify(path) != uid) {
                // SPDLOG_DEBUG("Skipping current map entry: unify(path) != uid. path='{}', uid='{}'.", path, uid);
                continue;
            }

            // Ensure there's an array for this UID
            if (!oldJson.contains(uid)) {
                // SPDLOG_DEBUG("UID '{}' does not exist in oldJson. Creating new array.", uid);
                oldJson[uid] = nlohmann::json::array();
            }

            auto& arr = oldJson[uid];
            bool found = false;
            for (auto& existingPath : arr) {
                if (existingPath.is_string() && existingPath.get<std::string>() == path) {
                    // SPDLOG_DEBUG("UID '{}' already has the path '{}'. Skipping addition.", uid, path);
                    found = true;
                    break;
                }
            }

            if (!found) {
                // SPDLOG_DEBUG("UID '{}' adding new path '{}'.", uid, path);
                arr.push_back(path);
            }
        }

        // 5. Write the resulting JSON to the file
        {
            std::ofstream outFile(filepath);
            if (!outFile.is_open()) {
                SPDLOG_ERROR("Failed to open file '{}' for writing.", filepath);
                return;
            }

            SPDLOG_DEBUG("Writing merged JSON to file '{}'.", filepath);
            outFile << oldJson.dump(4);
            outFile.close();

            SPDLOG_INFO("UUID map successfully merged and dumped to '{}'.", filepath);
        }
    }
}
