## When making usertypes constructible with Type():

```cpp
lua.new_usertype<UIConfig>("UIConfig",  
    sol::call_constructor, sol::constructors<UIConfig>())

```

## do not wrap sol::function in sol::optional if you don't want a bad time


## If facing entt "slot not available" errors, check out: https://github.com/skypjack/entt/issues/1095
<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
