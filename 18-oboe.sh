#!/usr/bin/env bash
set -euo pipefail

# Compilação única para arm64-v8a, com API mínima 24.
# Uso: execute este script sem argumentos.
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$HOME/Android/Sdk/ndk/29.0.14206865}"
VCPKG_ROOT="${VCPKG_ROOT:-$HOME/vcpkg}"
OVERLAY_TRIPLETS="${OVERLAY_TRIPLETS:-$VCPKG_ROOT/triplets/custom}"
PORT='oboe'

fail() {
    printf 'Erro: %s\n' "$*" >&2
    exit 1
}
(($# == 0)) || fail "Uso: $0 (sem argumentos; API mínima fixa em 24)"
API_MIN=24
API_MAX=24
[[ -x "$VCPKG_ROOT/vcpkg" ]] || fail "Executável ausente: $VCPKG_ROOT/vcpkg"
[[ -f "$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" ]] || fail "NDK inválido: $ANDROID_NDK_HOME"
command -v python3 >/dev/null || fail 'Python 3 é necessário para conferir as APIs suportadas pelo NDK.'

# Um nível acima do máximo do NDK pode ser silenciosamente reduzido pelo
# toolchain; rejeite isso para não rotular uma compilação com a API errada.
python3 - "$ANDROID_NDK_HOME/meta/platforms.json" "$API_MIN" "$API_MAX" <<'PYTHON'
import json, sys
try:
    with open(sys.argv[1], encoding='utf-8') as f:
        platforms = json.load(f)
    requested_min, requested_max = map(int, sys.argv[2:])
    supported_min, supported_max = int(platforms['min']), int(platforms['max'])
except (OSError, ValueError, KeyError) as exc:
    sys.exit(f'Erro ao consultar as APIs do NDK: {exc}')
if requested_min < supported_min or requested_max > supported_max:
    sys.exit(
        f'Erro: o NDK suporta APIs {supported_min} a {supported_max}; '
        f'a faixa solicitada foi {requested_min} a {requested_max}.\n'
        'Use um NDK que suporte a faixa ou passe uma faixa menor ao script.'
    )
PYTHON

mkdir -p "$OVERLAY_TRIPLETS"
# Valide todos os triplets antes de começar a instalar.
for ((api = API_MIN; api <= API_MAX; api++)); do
    triplet="arm64-android-api${api}"
    triplet_file="$OVERLAY_TRIPLETS/$triplet.cmake"
    content="$(
        cat <<CMAKE
set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME Android)
set(VCPKG_CMAKE_SYSTEM_VERSION ${api})
set(VCPKG_MAKE_BUILD_TRIPLET "--host=aarch64-linux-android")
set(VCPKG_CMAKE_CONFIGURE_OPTIONS -DANDROID_ABI=arm64-v8a)
CMAKE
    )"
    if [[ -e "$triplet_file" ]]; then
        [[ "$(cat "$triplet_file")" == "$content" ]] || fail "Triplet existente com configuração diferente: $triplet_file. Confira-o antes de reutilizar esse nome."
    else
        printf '%s\n' "$content" >"$triplet_file"
    fi
done

cd "$VCPKG_ROOT"
for ((api = API_MIN; api <= API_MAX; api++)); do
    triplet="arm64-android-api${api}"
    export ANDROID_PLATFORM="android-${api}"
    printf '\nInstalando %s — API %s — %s\n' "$PORT" "$api" "$triplet"
    ./vcpkg install "${PORT}:${triplet}" \
        --overlay-triplets="$OVERLAY_TRIPLETS" \
        --classic \
        --no-binarycaching
    printf 'Arquivos disponíveis em: %s/installed/%s/\n' "$VCPKG_ROOT" "$triplet"
    if [[ -d "$VCPKG_ROOT/installed/$triplet/lib" ]]; then
        ls -lh "$VCPKG_ROOT/installed/$triplet/lib/"
    fi
done
printf '\nInstalação concluída: %s, APIs %s a %s.\n' "$PORT" "$API_MIN" "$API_MAX"
