#include "include/speech_to_text_windows/speech_to_text_windows.h"
#include <flutter/plugin_registrar_windows.h>

#include "speech_to_text_windows_plugin.h"

void SpeechToTextWindowsRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  speech_to_text_windows::SpeechToTextWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}