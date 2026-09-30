#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# raylib para Android
#
# ABI : arm64-v8a
# API : 24
# NDK : 29
#
# Resultado principal:
#
#   libraylib.a
#
# Uso:
#
#   ./22-raylib.sh
#
# ============================================================

export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$HOME/Android/Sdk/ndk/29.0.14206865}"

VCPKG_ROOT="${VCPKG_ROOT:-$HOME/vcpkg}"
OVERLAY_TRIPLETS="${OVERLAY_TRIPLETS:-$VCPKG_ROOT/triplets/custom}"

API=24
ABI="arm64-v8a"
ARCH="arm64"

PORT="raylib"

TRIPLET="${ARCH}-android-api${API}"
TRIPLET_FILE="$OVERLAY_TRIPLETS/$TRIPLET.cmake"

fail()
{
    printf 'Erro: %s\n' "$*" >&2
    exit 1
}

(( $# == 0 )) ||
    fail "Uso: $0 (sem argumentos)"

[[ -x "$VCPKG_ROOT/vcpkg" ]] ||
    fail "Executável ausente: $VCPKG_ROOT/vcpkg"

[[ -f "$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" ]] ||
    fail "NDK inválido: $ANDROID_NDK_HOME"

[[ -f "$TRIPLET_FILE" ]] ||
    fail "Triplet não encontrado: $TRIPLET_FILE"

[[ -d "$VCPKG_ROOT/ports/$PORT" ]] ||
    fail "Port não encontrado: $PORT"

export ANDROID_PLATFORM="android-${API}"

printf '\n'
printf '========================================\n'
printf ' raylib para Android\n'
printf '========================================\n'
printf 'NDK     : %s\n' "$ANDROID_NDK_HOME"
printf 'vcpkg   : %s\n' "$VCPKG_ROOT"
printf 'ABI     : %s\n' "$ABI"
printf 'API     : %s\n' "$API"
printf 'Triplet : %s\n' "$TRIPLET"
printf 'Port    : %s\n' "$PORT"
printf '========================================\n'
printf '\n'

cd "$VCPKG_ROOT"

./vcpkg install \
    "${PORT}:${TRIPLET}" \
    --overlay-triplets="$OVERLAY_TRIPLETS" \
    --classic \
    --no-binarycaching

INSTALL_DIR="$VCPKG_ROOT/installed/$TRIPLET"

printf '\n'
printf '========================================\n'
printf ' raylib instalada\n'
printf '========================================\n'

printf '\nHeaders:\n'

find "$INSTALL_DIR/include" \
    -maxdepth 1 \
    -type f \
    \( -name 'raylib.h' \
       -o -name 'raymath.h' \
       -o -name 'rlgl.h' \) \
    -printf '%f\n' \
    | sort

printf '\nBibliotecas:\n'

find "$INSTALL_DIR/lib" \
    -maxdepth 1 \
    -type f \
    -name '*raylib*.a' \
    -printf '%f\n' \
    | sort

printf '\nCMake/configuração:\n'

find "$INSTALL_DIR/share" \
    -maxdepth 2 \
    -type f \
    \( -iname '*raylib*cmake' \
       -o -iname '*raylib*config*' \) \
    -print \
    2>/dev/null || true

printf '\n'
printf 'Prefixo: %s\n' "$INSTALL_DIR"
printf '\n'

