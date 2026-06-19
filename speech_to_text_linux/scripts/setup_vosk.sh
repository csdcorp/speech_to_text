#!/usr/bin/env bash
set -euo pipefail

VOSK_VERSION="${VOSK_VERSION:-0.3.45}"
VOSK_ARCH="${VOSK_ARCH:-x86_64}"
VOSK_PREFIX="${VOSK_PREFIX:-/opt/vosk}"
MODEL_NAME="${MODEL_NAME:-vosk-model-small-en-us-0.15}"

LIB_ARCHIVE="vosk-linux-${VOSK_ARCH}-${VOSK_VERSION}.zip"
LIB_URL="https://github.com/alphacep/vosk-api/releases/download/v${VOSK_VERSION}/${LIB_ARCHIVE}"
MODEL_ARCHIVE="${MODEL_NAME}.zip"
MODEL_URL="https://alphacephei.com/vosk/models/${MODEL_ARCHIVE}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SUDO=""
if [[ $EUID -ne 0 ]]; then
  SUDO="sudo"
fi

for cmd in curl unzip; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    print -u2 "missing required command: $cmd"
    exit 1
  fi
done

print "downloading $LIB_URL"
curl -L --fail -o "$TMP_DIR/$LIB_ARCHIVE" "$LIB_URL"

print "downloading $MODEL_URL"
curl -L --fail -o "$TMP_DIR/$MODEL_ARCHIVE" "$MODEL_URL"

print "extracting"
unzip -q "$TMP_DIR/$LIB_ARCHIVE" -d "$TMP_DIR"
unzip -q "$TMP_DIR/$MODEL_ARCHIVE" -d "$TMP_DIR"

LIB_SRC="$TMP_DIR/vosk-linux-${VOSK_ARCH}-${VOSK_VERSION}"

$SUDO mkdir -p "$VOSK_PREFIX/lib" "$VOSK_PREFIX/include"
$SUDO install -m 0755 "$LIB_SRC/libvosk.so" "$VOSK_PREFIX/lib/libvosk.so"
$SUDO install -m 0644 "$LIB_SRC/vosk_api.h" "$VOSK_PREFIX/include/vosk_api.h"
$SUDO rm -rf "$VOSK_PREFIX/$MODEL_NAME"
$SUDO cp -r "$TMP_DIR/$MODEL_NAME" "$VOSK_PREFIX/$MODEL_NAME"

print "installed Vosk $VOSK_VERSION to $VOSK_PREFIX"

export VOSK_PREFIX
# set to .zshrc & .bashrc
echo "export VOSK_PREFIX=$VOSK_PREFIX" | tee -a ~/.zshrc ~/.bashrc