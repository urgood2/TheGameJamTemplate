if(NOT DEFINED HTML_PATH OR NOT DEFINED SNIPPET_PATH)
    message(FATAL_ERROR "inject_snippet.cmake requires HTML_PATH and SNIPPET_PATH")
endif()

file(READ "${HTML_PATH}" HTML_CONTENT)
file(READ "${SNIPPET_PATH}" SNIPPET_CONTENT)

# Mirror the Windows patch behavior: inject before the generated js loader tag.
set(SCRIPT_TAG "<script async type=\"text/javascript\" src=\"raylib-cpp-cmake-template.js\"></script>")
string(REPLACE "${SCRIPT_TAG}" "${SNIPPET_CONTENT}\n${SCRIPT_TAG}" NEW_HTML_CONTENT "${HTML_CONTENT}")

if(NEW_HTML_CONTENT STREQUAL HTML_CONTENT)
    message(WARNING "inject_snippet: target script tag not found; no changes written.")
else()
    file(WRITE "${HTML_PATH}" "${NEW_HTML_CONTENT}")
endif()
