#pragma once

#include <any>
#include <string>
#include <unordered_map>
#include <stdexcept>
#include <vector>

namespace ai {

class Blackboard {
public:
    template<typename T>
    void set(const std::string& key, const T& value) {
        data_[key] = value;
    }

    template<typename T>
    T get(const std::string& key) const {
        if (data_.find(key) != data_.end()) {
            return std::any_cast<T>(data_.at(key));
        }
        throw std::runtime_error("Key not found");
    }

    bool contains(const std::string& key) const {
        return data_.find(key) != data_.end();
    }

    std::size_t size() const {
        return data_.size();
    }

    bool isEmpty() const {
        return data_.empty();
    }

    void clear() {
        data_.clear();
    }

    std::vector<std::string> getKeys() const {
        std::vector<std::string> keys;
        keys.reserve(data_.size());
        for (const auto& [key, _] : data_) {
            keys.push_back(key);
        }
        return keys;
    }

private:
    std::unordered_map<std::string, std::any> data_;
};

}  // namespace ai

// Backward compatibility: alias the old name to the new namespaced version
using Blackboard = ai::Blackboard;
