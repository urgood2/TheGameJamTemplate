# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file LICENSE.rst or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION ${CMAKE_VERSION}) # this file comes with cmake

# If CMAKE_DISABLE_SOURCE_CHANGES is set to true and the source directory is an
# existing directory in our source tree, calling file(MAKE_DIRECTORY) on it
# would cause a fatal error, even though it would be a no-op.
if(NOT EXISTS "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/_deps/lua-src")
  file(MAKE_DIRECTORY "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/_deps/lua-src")
endif()
file(MAKE_DIRECTORY
  "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/_deps/lua-build"
  "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/_deps/lua-subbuild/lua-populate-prefix"
  "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/_deps/lua-subbuild/lua-populate-prefix/tmp"
  "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/_deps/lua-subbuild/lua-populate-prefix/src/lua-populate-stamp"
  "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/_deps/lua-subbuild/lua-populate-prefix/src"
  "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/_deps/lua-subbuild/lua-populate-prefix/src/lua-populate-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/_deps/lua-subbuild/lua-populate-prefix/src/lua-populate-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/_deps/lua-subbuild/lua-populate-prefix/src/lua-populate-stamp${cfgdir}") # cfgdir has leading slash
endif()
