Sim. Eu faria um script voltado a um **kit Boost útil para aplicações Android/C++**, mas sem instalar o metapacote `boost`. Assim o vcpkg instala cada port separadamente e somente suas dependências transitivas.

```bash
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
# Uso:
#
#     ./build-boost-android.sh
#
# ============================================================

export ANDROID_NDK_HOME="${
    ANDROID_NDK_HOME:-$HOME/Android/Sdk/ndk/29.0.14206865
}"

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
# Não adicione "boost" aqui.
# Ele é o metapacote do conjunto completo.
#
# Alguns componentes são header-only. Nesse caso é normal não
# aparecer um libboost_*.a correspondente.
#

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
    boost-span
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
    # Estruturas / algoritmos
    # --------------------------------------------------------
    boost-bimap
    boost-circular-buffer
    boost-flat-map
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
    # Assíncrono / rede
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

fail()
{
    printf 'Erro: %s\n' "$*" >&2
    exit 1
}

# ============================================================
# Argumentos
# ============================================================

(( $# == 0 )) ||
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
# Validação da API
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
# Criação do triplet
# ============================================================

mkdir -p "$OVERLAY_TRIPLETS"

content="$(
    cat <<CMAKE
set(VCPKG_TARGET_ARCHITECTURE arm64)

set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME Android)
set(VCPKG_CMAKE_SYSTEM_VERSION ${API})

set(
    VCPKG_MAKE_BUILD_TRIPLET
    "--host=aarch64-linux-android"
)

set(
    VCPKG_CMAKE_CONFIGURE_OPTIONS
    -DANDROID_ABI=${ABI}
)
CMAKE
)"

if [[ -e "$TRIPLET_FILE" ]]; then

    [[ "$(cat "$TRIPLET_FILE")" == "$content" ]] ||
        fail \
            "Triplet existente com configuração diferente: \
$TRIPLET_FILE"

else

    printf '%s\n' "$content" >"$TRIPLET_FILE"

fi

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
printf 'Pacotes : %d\n' "${#BOOST_PORTS[@]}"
printf '========================================\n'
printf '\n'

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
printf '\nDiretório:\n%s\n' "$INSTALL_DIR"

# ============================================================
# Bibliotecas estáticas
# ============================================================

printf '\nBibliotecas estáticas instaladas:\n\n'

if [[ -d "$INSTALL_DIR/lib" ]]; then

    find "$INSTALL_DIR/lib" \
        -maxdepth 1 \
        -type f \
        -name '*.a' \
        -printf '%f\n' \
        | sort

else

    printf 'Nenhuma pasta lib encontrada.\n'

fi

# ============================================================
# Packages CMake
# ============================================================

printf '\nPackages disponíveis em share/:\n\n'

if [[ -d "$INSTALL_DIR/share" ]]; then

    find "$INSTALL_DIR/share" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -printf '%f\n' \
        | grep '^boost-' \
        | sort || true

fi

printf '\n'
printf 'Boost Android concluído.\n'
printf '\n'
```

### O conjunto que escolhi

Não coloquei simplesmente todos os ports do Boost. Selecionei os que têm alguma utilidade plausível no Android nativo.

Para **rede**, eu considero especialmente interessantes:

```text
boost-asio
boost-beast
boost-url
boost-system
```

Isso permite posteriormente estudarmos algo como:

```text
Android/Kotlin
     │
     JNI
     │
     C++
     │
     ├── Boost.Asio ─── TCP / UDP / timers / async
     │
     ├── Boost.Beast ── HTTP / WebSocket
     │
     └── Boost.URL ──── manipulação de URLs
```

Isso combina muito bem com o que você está fazendo agora com curl.

Para **multithreading/concorrência**:

```text
boost-atomic
boost-chrono
boost-lockfree
boost-thread
```

Embora C++17/20 já resolva muita coisa com `std::thread`, `std::mutex`, `std::atomic` etc., Boost ainda é interessante para `lockfree` e para estudar projetos que dependem dessas APIs.

Para **dados**:

```text
boost-json
boost-serialization
boost-uuid
boost-regex
boost-charconv
```

Eu destacaria particularmente:

```cpp
boost::json
```

para Android + JNI. Por exemplo, o C++ pode retornar uma representação JSON para Kotlin em vez de criar interfaces JNI enormes.

Para **matemática**, coloquei:

```text
boost-math
boost-multiprecision
boost-rational
```

`Boost.Multiprecision` é especialmente interessante para seus exemplos matemáticos:

```cpp
boost::multiprecision::cpp_int
boost::multiprecision::cpp_dec_float_50
```

permitindo inteiros arbitrariamente grandes e cálculos com precisão maior.

### Uma ressalva sobre "pacotes separados"

O resultado não será literalmente:

```text
boost-system/
boost-filesystem/
boost-json/
...
```

cada um completamente independente no disco.

O vcpkg usa o mesmo prefixo:

```text
~/vcpkg/installed/arm64-android-api24/
```

e agrega nele os headers, bibliotecas e arquivos CMake de todos os ports instalados.

Mas você terá bibliotecas compiladas separadas quando o componente efetivamente produz uma biblioteca:

```text
lib/
├── libboost_atomic.a
├── libboost_charconv.a
├── libboost_chrono.a
├── libboost_context.a
├── libboost_filesystem.a
├── libboost_json.a
├── libboost_program_options.a
├── libboost_regex.a
├── libboost_serialization.a
├── libboost_thread.a
├── libboost_url.a
└── ...
```

e **não um gigantesco `libboost.a`**.

Muitos outros componentes são header-only, portanto é correto que não apareça um `.a` correspondente.

Eu deixei `--no-binarycaching` porque estava no seu script original, mas, para Boost, eu consideraria seriamente removê-lo depois dos primeiros testes: há muitas dependências compartilhadas entre esses ports, e o cache binário do vcpkg pode economizar bastante tempo em reconstruções.

