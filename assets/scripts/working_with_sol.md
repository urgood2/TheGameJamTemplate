## When making usertypes constructible with Type():

```cpp
lua.new_usertype<UIConfig>("UIConfig",  
    sol::call_constructor, sol::constructors<UIConfig>())

```

## do not wrap sol::function in sol::optional if you don't want a bad time