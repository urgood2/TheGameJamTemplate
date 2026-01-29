

To profile Lua code using tracy, include the tracy/TracyLua.hpp header file in your Lua wrapper and execute tracy::LuaRegister( lua_State* ) function to add instrumentation support. In your Lua code, add tracy.ZoneBegin() and tracy.ZoneEnd() calls to mark execution zones. Double check if you have included all return paths! Use tracy.ZoneBeginN( name ) to set zone name. Use tracy.ZoneText( text ) to set zone text. Use tracy.Message( text ) to send messages. Use tracy.ZoneName( text ) to set zone name on a per-call basis.

Even if tracy is disabled, you still have to pay the no-op function call cost. To prevent that you may want to use the tracy::LuaRemove( char* script ) function, which will replace instrumentation calls with whitespace. This function does nothing if profiler is enabled.
<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
