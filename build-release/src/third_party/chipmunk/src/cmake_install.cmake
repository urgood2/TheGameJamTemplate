# Install script for directory: /Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/src

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/usr/local")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

# Set path to fallback-tool for dependency-resolution.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/usr/bin/objdump")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/lib/libchipmunk.a")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/lib" TYPE STATIC_LIBRARY FILES "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/src/third_party/chipmunk/src/libchipmunk.a")
  if(EXISTS "$ENV{DESTDIR}/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/lib/libchipmunk.a" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/lib/libchipmunk.a")
    execute_process(COMMAND "/usr/bin/ranlib" "$ENV{DESTDIR}/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/lib/libchipmunk.a")
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/chipmunk" TYPE FILE FILES
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/chipmunk.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/chipmunk_ffi.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/chipmunk_private.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/chipmunk_structs.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/chipmunk_types.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/chipmunk_unsafe.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpArbiter.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpBB.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpBody.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpConstraint.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpDampedRotarySpring.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpDampedSpring.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpGearJoint.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpGrooveJoint.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpHastySpace.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpMarch.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpPinJoint.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpPivotJoint.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpPolyShape.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpPolyline.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpRatchetJoint.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpRobust.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpRotaryLimitJoint.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpShape.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpSimpleMotor.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpSlideJoint.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpSpace.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpSpatialIndex.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpTransform.h"
    "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/src/third_party/chipmunk/include/chipmunk/cpVect.h"
    )
endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
if(CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "/Users/joshuashin/conductor/workspaces/TheGameJamTemplate/boston/build-release/src/third_party/chipmunk/src/install_local_manifest.txt"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
