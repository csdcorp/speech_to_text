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

# if not locally found, download a prebuilt vosk & set VOSK_LIBRARY and VOSK_INCLUDE_DIR to the downloaded paths
option(VOSK_AUTO_DOWNLOAD
  "Download a prebuilt Vosk SDK when one is not found locally" ON)
set(VOSK_VERSION "0.3.45" CACHE STRING
  "Vosk SDK version to fetch when VOSK_AUTO_DOWNLOAD is enabled")

if((NOT VOSK_LIBRARY OR NOT VOSK_INCLUDE_DIR) AND VOSK_AUTO_DOWNLOAD)
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64|AMD64)$")
    set(_vosk_arch "x86_64")
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
    set(_vosk_arch "aarch64")
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^arm")
    set(_vosk_arch "armv7l")
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "riscv64")
    set(_vosk_arch "riscv64")
  else()
    message(FATAL_ERROR
      "Vosk auto-download does not support processor '${CMAKE_SYSTEM_PROCESSOR}'. "
      "Install Vosk manually and set VOSK_DIR, or pass -DVOSK_AUTO_DOWNLOAD=OFF.")
  endif()

  # xdg cache home is $HOME/.cache
  if(DEFINED ENV{XDG_CACHE_HOME} AND NOT "$ENV{XDG_CACHE_HOME}" STREQUAL "")
    set(_vosk_cache_root "$ENV{XDG_CACHE_HOME}/speech_to_text_linux")
  elseif(DEFINED ENV{HOME} AND NOT "$ENV{HOME}" STREQUAL "")
    set(_vosk_cache_root "$ENV{HOME}/.cache/speech_to_text_linux")
  else()
    set(_vosk_cache_root "${CMAKE_BINARY_DIR}/_vosk")
  endif()

  set(_vosk_name "vosk-linux-${_vosk_arch}-${VOSK_VERSION}")
  set(_vosk_url
    "https://github.com/alphacep/vosk-api/releases/download/v${VOSK_VERSION}/${_vosk_name}.zip")
  set(_vosk_dir "${_vosk_cache_root}/${_vosk_name}")
  set(_vosk_zip "${_vosk_cache_root}/${_vosk_name}.zip")

  if(NOT EXISTS "${_vosk_dir}/libvosk.so" OR NOT EXISTS "${_vosk_dir}/vosk_api.h")
    message(STATUS "speech_to_text_linux: fetching Vosk SDK from ${_vosk_url}")
    file(MAKE_DIRECTORY "${_vosk_cache_root}")
    file(DOWNLOAD "${_vosk_url}" "${_vosk_zip}"
      SHOW_PROGRESS
      STATUS _vosk_dl_status)
    list(GET _vosk_dl_status 0 _vosk_dl_code)
    if(NOT _vosk_dl_code EQUAL 0)
      list(GET _vosk_dl_status 1 _vosk_dl_msg)
      file(REMOVE "${_vosk_zip}")
      message(FATAL_ERROR "Failed to download Vosk SDK: ${_vosk_dl_msg}")
    endif()

    find_program(_vosk_unzip unzip)
    if(NOT _vosk_unzip)
      file(REMOVE "${_vosk_zip}")
      message(FATAL_ERROR
        "speech_to_text_linux requires 'unzip' to extract the Vosk SDK. "
        "Install it via your package manager (e.g. 'sudo pacman -S unzip' / 'sudo apt install unzip').")
    endif()
    execute_process(
      COMMAND "${_vosk_unzip}" -q "${_vosk_zip}" -d "${_vosk_cache_root}"
      RESULT_VARIABLE _vosk_extract_result)
    file(REMOVE "${_vosk_zip}")
    if(NOT _vosk_extract_result EQUAL 0)
      message(FATAL_ERROR "Failed to extract Vosk SDK archive")
    endif()
  endif()

  set(VOSK_LIBRARY "${_vosk_dir}/libvosk.so" CACHE FILEPATH "" FORCE)
  set(VOSK_INCLUDE_DIR "${_vosk_dir}" CACHE PATH "" FORCE)
endif()

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
