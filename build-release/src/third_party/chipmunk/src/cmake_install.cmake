# Install script for directory: /data/projects/roguelike-4/src/third_party/chipmunk/src

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

# Install shared libraries without execute permission?
if(NOT DEFINED CMAKE_INSTALL_SO_NO_EXE)
  set(CMAKE_INSTALL_SO_NO_EXE "1")
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
   "/data/projects/roguelike-4/build-release/lib/libchipmunk.a")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "/data/projects/roguelike-4/build-release/lib" TYPE STATIC_LIBRARY FILES "/data/projects/roguelike-4/build-release/src/third_party/chipmunk/src/libchipmunk.a")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/chipmunk" TYPE FILE FILES
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/chipmunk.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/chipmunk_ffi.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/chipmunk_private.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/chipmunk_structs.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/chipmunk_types.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/chipmunk_unsafe.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpArbiter.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpBB.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpBody.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpConstraint.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpDampedRotarySpring.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpDampedSpring.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpGearJoint.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpGrooveJoint.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpHastySpace.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpMarch.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpPinJoint.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpPivotJoint.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpPolyShape.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpPolyline.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpRatchetJoint.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpRobust.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpRotaryLimitJoint.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpShape.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpSimpleMotor.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpSlideJoint.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpSpace.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpSpatialIndex.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpTransform.h"
    "/data/projects/roguelike-4/src/third_party/chipmunk/include/chipmunk/cpVect.h"
    )
endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
if(CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "/data/projects/roguelike-4/build-release/src/third_party/chipmunk/src/install_local_manifest.txt"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
