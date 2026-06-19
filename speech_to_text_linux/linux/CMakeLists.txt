# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "speech_to_text_linux")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "speech_to_text_linux_plugin")

# Locate the system dependencies the native plugin needs.
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)
pkg_check_modules(PULSE REQUIRED IMPORTED_TARGET libpulse-simple)

# Locate VOSK library via VOSK_DIR / ENV
find_library(VOSK_LIBRARY
  NAMES vosk libvosk
  HINTS "${VOSK_DIR}" "$ENV{VOSK_DIR}"
  PATH_SUFFIXES lib lib64
  PATHS /usr/local/lib /usr/lib
)
find_path(VOSK_INCLUDE_DIR
  NAMES vosk_api.h
  HINTS "${VOSK_DIR}" "$ENV{VOSK_DIR}"
  PATH_SUFFIXES include
  PATHS /usr/local/include /usr/include
)

if(NOT VOSK_LIBRARY OR NOT VOSK_INCLUDE_DIR)
  message(FATAL_ERROR
    "Could not find the Vosk library (libvosk.so) and/or vosk_api.h. "
    "Download a Vosk release from https://github.com/alphacep/vosk-api/releases "
    "and either install it to a standard prefix or set VOSK_DIR to the folder "
    "that contains libvosk.so and vosk_api.h.")
endif()

add_library(${PLUGIN_NAME} SHARED
  "speech_to_text_linux_plugin.cc"
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
set_property(TARGET ${PLUGIN_NAME} PROPERTY CXX_STANDARD 17)
set_property(TARGET ${PLUGIN_NAME} PROPERTY CXX_STANDARD_REQUIRED ON)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${VOSK_INCLUDE_DIR}")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::PULSE)
target_link_libraries(${PLUGIN_NAME} PRIVATE "${VOSK_LIBRARY}")

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(speech_to_text_linux_bundled_libraries
  "${VOSK_LIBRARY}"
  PARENT_SCOPE
)
