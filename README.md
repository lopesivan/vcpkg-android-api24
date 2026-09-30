# Bibliotecas Android: compilação única para API mínima 24

Um script independente por biblioteca, sem argumentos, para arm64-v8a.
Cada biblioteca é compilada para API mínima 24 e pode ser usada em Android 24
ou posterior, inclusive 37, respeitando a compatibilidade da própria biblioteca
e de suas dependências. Não são geradas variantes por API.

## Executar

```bash
./01-curl.sh
./02-libssh2.sh
./08-opencv4.sh
```

Para instalar todas, em sequência, interrompendo na primeira falha:

```bash
for script in ./*.sh; do
    bash "$script" || break
done
```

Bibliotecas: curl, libssh2, sqlite3, simdjson, glm, zstd, bullet3,
opencv4, eigen3, fmt, spdlog, libsodium, lua, meshoptimizer, openssl e zlib.
OpenCV: somente core, dnn, jpeg e png, sem features padrão.

## Configuração

- NDK padrão: `$HOME/Android/Sdk/ndk/29.0.14206865`
- vcpkg padrão: `$HOME/vcpkg`
- Triplets customizados: `$VCPKG_ROOT/triplets/custom`

É possível sobrescrever `ANDROID_NDK_HOME`, `VCPKG_ROOT` e `OVERLAY_TRIPLETS`
no ambiente. Requer Bash, Python 3, vcpkg inicializado, NDK e ferramentas
exigidas pelos ports. Os scripts não instalam essas ferramentas.

Cada script cria ou confere o mesmo triplet:
`triplets/custom/arm64-android-api24.cmake`.
Configuração: arquitetura arm64, ABI arm64-v8a, bibliotecas estáticas,
CRT dinâmica e `VCPKG_CMAKE_SYSTEM_VERSION=24`.
O triplet original `arm64-android.cmake` não é alterado.

Resultado: `$VCPKG_ROOT/installed/arm64-android-api24/`.
Dependências são instaladas automaticamente e reutilizadas no mesmo triplet.
GLM e Eigen3 são normalmente header-only; consulte também `include/`.
`--no-binarycaching` desativa o cache binário, mas não força reconstrução
de pacotes já instalados. Nenhum pacote é removido automaticamente.

No aplicativo use `minSdk = 24` e o mesmo ABI. `compileSdk` e `targetSdk`
podem ser superiores. Não é necessário um NDK que suporte a API 37 para
compilar estas bibliotecas com mínimo 24.

Verificado: sintaxe Bash e execução simulada. Nenhuma biblioteca foi
compilada ou instalada durante a criação dos scripts.
