## When making usertypes constructible with Type():

```cpp
lua.new_usertype<UIConfig>("UIConfig",  
    sol::call_constructor, sol::constructors<UIConfig>())

```