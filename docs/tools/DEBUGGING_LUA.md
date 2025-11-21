add to launch.json and access from the run and debug menu.

```json
{
    "name": "Debug Lua Scripts",
    "type": "lua-local",
    "request": "launch",
    "program": {
        "command": "${workspaceRoot}/build/raylib-cpp-cmake-template"
    },
    "cwd": "${workspaceFolder}",
    "args": [ ],
    "scriptRoots": [
        "${workspaceRoot}/assets/scripts/core",
        "${workspaceRoot}/assets/scripts/"
    ]
}
```