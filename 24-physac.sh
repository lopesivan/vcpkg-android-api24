#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Physac para Android
#
# Physac é HEADER-ONLY.
#
# Resultado esperado:
#
#   physac.h
#
# e NÃO:
#
#   libphysac.a
#
# Uso:
#
#   ./24-physac.sh
#
# ============================================================

export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$HOME/Android/Sdk/ndk/29.0.14206865}"

VCPKG_ROOT="${VCPKG_ROOT:-$HOME/vcpkg}"
OVERLAY_TRIPLETS="${OVERLAY_TRIPLETS:-$VCPKG_ROOT/triplets/custom}"

API=24
ARCH="arm64"

PORT="physac"

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
    fail "Port não encontrado no vcpkg: $PORT"

export ANDROID_PLATFORM="android-${API}"

printf '\n'
printf '========================================\n'
printf ' Physac para Android\n'
printf '========================================\n'
printf 'Triplet : %s\n' "$TRIPLET"
printf 'Tipo    : header-only\n'
printf '========================================\n'
printf '\n'

cd "$VCPKG_ROOT"

./vcpkg install \
    "${PORT}:${TRIPLET}" \
    --overlay-triplets="$OVERLAY_TRIPLETS" \
    --classic \
    --no-binarycaching

INSTALL_DIR="$VCPKG_ROOT/installed/$TRIPLET"

printf '\nHeaders Physac:\n\n'

find "$INSTALL_DIR/include" \
    -type f \
    -name 'physac.h' \
    -print

printf '\n'
printf 'Instalação concluída.\n'
printf 'Prefixo: %s\n' "$INSTALL_DIR"
printf '\n'

