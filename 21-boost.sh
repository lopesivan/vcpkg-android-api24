#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Boost para Android
#
# ABI : arm64-v8a
# API : 24
# NDK : 29
#
# Instala componentes Boost individualmente, evitando:
#
#     vcpkg install boost
#
# O triplet deve existir previamente em:
#
#     ~/vcpkg/triplets/custom/arm64-android-api24.cmake
#
# Uso:
#
#     ./21-boost.sh
#
# ============================================================

export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$HOME/Android/Sdk/ndk/29.0.14206865}"

VCPKG_ROOT="${VCPKG_ROOT:-$HOME/vcpkg}"
OVERLAY_TRIPLETS="${OVERLAY_TRIPLETS:-$VCPKG_ROOT/triplets/custom}"

API=24
ABI="arm64-v8a"
ARCH="arm64"

TRIPLET="${ARCH}-android-api${API}"
TRIPLET_FILE="$OVERLAY_TRIPLETS/$TRIPLET.cmake"

# ============================================================
# Componentes Boost
# ============================================================
#
# NÃO adicionar:
#
#     boost
#
# porque "boost" é o metapacote completo.
#
# Cada componente abaixo será solicitado individualmente ao
# vcpkg. Dependências transitivas serão resolvidas normalmente.
#
# Alguns componentes são header-only. Portanto, é normal que
# nem todo boost-* abaixo produza um libboost_*.a.
# ============================================================

BOOST_PORTS=(

    # --------------------------------------------------------
    # Base / utilitários
    # --------------------------------------------------------

    boost-algorithm
    boost-any
    boost-array
    boost-assert
    boost-container
    boost-container-hash
    boost-conversion
    boost-core
    boost-dynamic-bitset
    boost-endian
    boost-functional
    boost-optional
    boost-scope
    boost-smart-ptr
    boost-static-assert
    boost-type-index
    boost-type-traits
    boost-variant
    boost-variant2

    # --------------------------------------------------------
    # Strings / parsing / dados
    # --------------------------------------------------------

    boost-charconv
    boost-format
    boost-json
    boost-lexical-cast
    boost-regex
    boost-tokenizer
    boost-url
    boost-uuid

    # --------------------------------------------------------
    # Matemática
    # --------------------------------------------------------

    boost-math
    boost-multiprecision
    boost-rational

    # --------------------------------------------------------
    # Estruturas de dados / algoritmos
    # --------------------------------------------------------

    boost-bimap
    boost-circular-buffer
    boost-graph
    boost-heap
    boost-intrusive
    boost-multi-array
    boost-multi-index
    boost-unordered

    # --------------------------------------------------------
    # Sistema / filesystem
    # --------------------------------------------------------

    boost-filesystem
    boost-system

    # --------------------------------------------------------
    # Concorrência
    # --------------------------------------------------------

    boost-atomic
    boost-chrono
    boost-lockfree
    boost-thread

    # --------------------------------------------------------
    # Rede / assíncrono
    # --------------------------------------------------------

    boost-asio
    boost-beast

    # --------------------------------------------------------
    # Coroutines
    # --------------------------------------------------------

    boost-context
    boost-coroutine
    boost-coroutine2

    # --------------------------------------------------------
    # Serialização
    # --------------------------------------------------------

    boost-serialization

    # --------------------------------------------------------
    # Programação funcional
    # --------------------------------------------------------

    boost-function
    boost-bind
)

# ============================================================
# Funções
# ============================================================

fail() {
    printf 'Erro: %s\n' "$*" >&2
    exit 1
}

# ============================================================
# Argumentos
# ============================================================

(($# == 0)) ||
    fail "Uso: $0 (sem argumentos)"

# ============================================================
# Verificação do ambiente
# ============================================================

[[ -x "$VCPKG_ROOT/vcpkg" ]] ||
    fail "Executável ausente: $VCPKG_ROOT/vcpkg"

[[ -f "$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" ]] ||
    fail "NDK inválido: $ANDROID_NDK_HOME"

command -v python3 >/dev/null ||
    fail "Python 3 é necessário para conferir as APIs do NDK."

# ============================================================
# Verificação do triplet
# ============================================================
#
# Este script NÃO cria e NÃO modifica o triplet.
#
# O mesmo triplet pode ser compartilhado por:
#
#     curl
#     openssl
#     boost-*
#     opencv
#     zlib
#     libpng
#     jpeg
#     etc.
#
# ============================================================

[[ -f "$TRIPLET_FILE" ]] ||
    fail "Triplet não encontrado: $TRIPLET_FILE"

# ============================================================
# Validação da API suportada pelo NDK
# ============================================================

python3 \
    - "$ANDROID_NDK_HOME/meta/platforms.json" "$API" <<'PYTHON'
import json
import sys

path = sys.argv[1]
requested = int(sys.argv[2])

try:
    with open(path, encoding="utf-8") as f:
        platforms = json.load(f)

    supported_min = int(platforms["min"])
    supported_max = int(platforms["max"])

except (OSError, ValueError, KeyError) as exc:
    sys.exit(
        f"Erro ao consultar as APIs do NDK: {exc}"
    )

if not supported_min <= requested <= supported_max:
    sys.exit(
        f"Erro: o NDK suporta APIs "
        f"{supported_min} a {supported_max}; "
        f"API solicitada: {requested}."
    )
PYTHON

# ============================================================
# Configuração Android
# ============================================================

export ANDROID_PLATFORM="android-${API}"

# ============================================================
# Informações
# ============================================================

printf '\n'
printf '========================================\n'
printf ' Boost para Android\n'
printf '========================================\n'
printf 'NDK     : %s\n' "$ANDROID_NDK_HOME"
printf 'vcpkg   : %s\n' "$VCPKG_ROOT"
printf 'ABI     : %s\n' "$ABI"
printf 'API     : %s\n' "$API"
printf 'Triplet : %s\n' "$TRIPLET"
printf 'Arquivo : %s\n' "$TRIPLET_FILE"
printf 'Pacotes : %d\n' "${#BOOST_PORTS[@]}"
printf '========================================\n'
printf '\n'

# ============================================================
# Mostra o triplet utilizado
# ============================================================

printf 'Configuração do triplet:\n'
printf '%s\n' '----------------------------------------'
cat "$TRIPLET_FILE"
printf '%s\n' '----------------------------------------'
printf '\n'

# ============================================================
# Validação dos ports
# ============================================================

printf 'Validando ports Boost...\n\n'

INVALID_PORTS=()

for port in "${BOOST_PORTS[@]}"; do
    if [[ ! -d "$VCPKG_ROOT/ports/$port" ]]; then
        INVALID_PORTS+=("$port")
    fi
done

if ((${#INVALID_PORTS[@]} > 0)); then
    printf 'Erro: os seguintes ports não existem no vcpkg:\n\n' >&2

    for port in "${INVALID_PORTS[@]}"; do
        printf '  - %s\n' "$port" >&2
    done

    printf '\n' >&2
    exit 1
fi

printf 'Todos os %d ports existem.\n\n' "${#BOOST_PORTS[@]}"

# ============================================================
# Instalação
# ============================================================

cd "$VCPKG_ROOT"

TOTAL="${#BOOST_PORTS[@]}"
CURRENT=0

for port in "${BOOST_PORTS[@]}"; do

    ((++CURRENT))

    printf '\n'
    printf '========================================\n'
    printf '[%d/%d] %s\n' \
        "$CURRENT" \
        "$TOTAL" \
        "$port"
    printf '========================================\n'
    printf '\n'

    ./vcpkg install \
        "${port}:${TRIPLET}" \
        --overlay-triplets="$OVERLAY_TRIPLETS" \
        --classic \
        --no-binarycaching

done

# ============================================================
# Resultado
# ============================================================

INSTALL_DIR="$VCPKG_ROOT/installed/$TRIPLET"

printf '\n'
printf '========================================\n'
printf ' Instalação concluída\n'
printf '========================================\n'
printf '\n'

printf 'Diretório:\n'
printf '  %s\n' "$INSTALL_DIR"

# ============================================================
# Bibliotecas estáticas
# ============================================================

printf '\n'
printf 'Bibliotecas estáticas instaladas:\n'
printf '\n'

if [[ -d "$INSTALL_DIR/lib" ]]; then

    find "$INSTALL_DIR/lib" \
        -maxdepth 1 \
        -type f \
        -name '*.a' \
        -printf '%f\n' |
        sort

else

    printf 'Nenhuma pasta lib encontrada.\n'

fi

# ============================================================
# Bibliotecas Boost especificamente
# ============================================================

printf '\n'
printf 'Bibliotecas Boost compiladas:\n'
printf '\n'

if [[ -d "$INSTALL_DIR/lib" ]]; then

    BOOST_LIBS="$(
        find "$INSTALL_DIR/lib" \
            -maxdepth 1 \
            -type f \
            -name 'libboost_*.a' \
            -printf '%f\n' |
            sort
    )"

    if [[ -n "$BOOST_LIBS" ]]; then
        printf '%s\n' "$BOOST_LIBS"
    else
        printf 'Nenhum libboost_*.a encontrado.\n'
    fi

fi

# ============================================================
# Packages CMake
# ============================================================

printf '\n'
printf 'Packages Boost disponíveis em share/:\n'
printf '\n'

if [[ -d "$INSTALL_DIR/share" ]]; then

    find "$INSTALL_DIR/share" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -printf '%f\n' |
        grep '^boost-' |
        sort ||
        true

fi

# ============================================================
# Resumo
# ============================================================

printf '\n'
printf '========================================\n'
printf ' Boost Android concluído\n'
printf '========================================\n'
printf 'ABI     : %s\n' "$ABI"
printf 'API     : %s\n' "$API"
printf 'Triplet : %s\n' "$TRIPLET"
printf 'Prefixo : %s\n' "$INSTALL_DIR"
printf '========================================\n'
printf '\n'
