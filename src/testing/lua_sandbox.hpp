#pragma once
// TODO: Implement lua_sandbox

namespace sol {
class state;
}

namespace testing {

class LuaSandbox {
public:
    void apply(sol::state& lua);
    bool is_enabled() const;
    void set_enabled(bool enabled);

private:
    bool enabled_ = true;
};

} // namespace testing
