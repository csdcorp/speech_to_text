# speech_to_text_linux

A Linux implementation of the [`speech_to_text`](https://github.com/csdcorp/speech_to_text) plugin.

Linux does not ship a system speech recognition engine, so this package performs recognition
**offline** using the open-source [Vosk](https://alphacephei.com/vosk/) toolkit. Microphone audio is captured through PulseAudio as 16 kHz mono PCM and streamed to Vosk, which produces partial and final results in real time. It means we do not need to use any cloud provider, or expensive AI-based compute.

Vosk is licensed by [Apache 2.0](github.com/alphacep/vosk-api/blob/master/COPYING).

## Usage

This package is endorsed, which means you can use `speech_to_text` normally and this implementation is automatically included on Linux. See
[speech_to_text](https://github.com/csdcorp/speech_to_text/blob/main/speech_to_text/README.md).

## Build dependencies

Install the development packages required to build the native plugin:

```bash
# Debian / Ubuntu
sudo apt-get install libgtk-3-dev libpulse-dev

# Fedora
sudo dnf install gtk3-devel pulseaudio-libs-devel

# Arch Linux (based)
sudo pacman -S gtk3 libpulse base-devel
```

## Vosk library and model

The plugin links against `libvosk.so` and needs the matching `vosk_api.h` header at build time, plus a language model directory at runtime.

1. Download a Vosk release for Linux (containing `libvosk.so` and `vosk_api.h`) from
   <https://github.com/alphacep/vosk-api/releases> and a model (for example
   `vosk-model-small-en-us-0.15`) from <https://alphacephei.com/vosk/models>.
2. Make the library and header discoverable by the build. Either install them into a standard
   location (`/usr/local/lib`, `/usr/local/include`) or set `VOSK_DIR` to the folder that contains
   them before building:

   ```bash
   export VOSK_DIR=/opt/vosk
   ```

   The build copies the resolved `libvosk.so` into the application bundle automatically.
3. Unpack the model somewhere on disk and pass its path to `initialize` via a platform option:

   ```dart
   await speech.initialize(
     options: [
       SpeechConfigOption('linux', 'modelPath', '/opt/vosk/vosk-model-small-en-us-0.15'),
     ],
   );
   ```

## Notes / Odd Behaviour

* Microphone access is unrestricted under a normal desktop session, so `hasPermission` returns `true`. Sandboxed packaging (Flatpak/Snap) may still require granting microphone access. Which may need to be done via another API? Will need to have a look.
* Vosk does not expose a locale enumeration API; `locales()` reports the locale derived from the configured model (defaulting to `en_US`).
