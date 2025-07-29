cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "speech_to_text_windows")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must not be changed
set(PLUGIN_NAME "speech_to_text_windows_plugin")

list(APPEND PLUGIN_SOURCES
  "speech_to_text_windows_plugin.cpp"
  "speech_to_text_windows_plugin.h"
)

# Define the plugin library target
add_library(${PLUGIN_NAME} SHARED
  "include/speech_to_text_windows/speech_to_text_windows.h"
  "speech_to_text_windows.cpp"
  ${PLUGIN_SOURCES}
)

# Apply standard Flutter plugin settings
apply_standard_settings(${PLUGIN_NAME})

# Set C++ standard
set_property(TARGET ${PLUGIN_NAME} PROPERTY CXX_STANDARD 17)
set_property(TARGET ${PLUGIN_NAME} PROPERTY CXX_STANDARD_REQUIRED ON)

# Configure target properties
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
)

# Define preprocessor macros
target_compile_definitions(${PLUGIN_NAME} PRIVATE 
  FLUTTER_PLUGIN_IMPL
  WIN32_LEAN_AND_MEAN
  NOMINMAX
  _CRT_SECURE_NO_WARNINGS      # Disable CRT security warnings
  _WINSOCK_DEPRECATED_NO_WARNINGS  # Disable deprecated Winsock warnings
)

# Disable specific warnings that are treated as errors
if(MSVC)
  target_compile_options(${PLUGIN_NAME} PRIVATE 
    /wd4996  # Disable 'function was declared deprecated' warnings
    /wd4245  # Disable signed/unsigned mismatch warnings
    /W3      # Use warning level 3 instead of 4
  )
  # Also apply these settings to the main runner target if possible
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /wd4996")
endif()

# Include directories
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

# Make sure the plugin headers are available with correct path
target_include_directories(${PLUGIN_NAME} PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}"
)

# Link Flutter libraries
target_link_libraries(${PLUGIN_NAME} PRIVATE 
  flutter 
  flutter_wrapper_plugin
)

# Link Windows SAPI libraries (without ATL)
target_link_libraries(${PLUGIN_NAME} PRIVATE 
  ole32           # For COM
  oleaut32        # For COM automation
  uuid            # For GUIDs
  sapi            # For Speech API
)

# List of absolute paths to libraries that should be bundled with the plugin
set(speech_to_text_windows_bundled_libraries
  ""
  PARENT_SCOPE
)