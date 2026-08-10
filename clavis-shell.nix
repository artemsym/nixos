{ lib
, stdenv
, fetchFromGitHub
, cmake
, patchelf
, pkg-config
, fftw
, pipewire
, qt6
, kdePackages
, git
}:
let
  cavacore = stdenv.mkDerivation {
    pname = "cavacore";
    version = "0.10.7";
    src = fetchFromGitHub {
      owner = "karlstav";
      repo = "cava";
      rev = "0.10.7";
      hash = "sha256-eOGUDGGlja5Cq8XTJFRqyP6qyaoxOJm09vZrlk4KS9k=";
    };
    nativeBuildInputs = [ cmake pkg-config ];
    buildInputs = [ fftw pipewire ];
    dontInstall = true;
    postBuild = ''
      mkdir -p $out/lib $out/include/cava $out/lib/pkgconfig
      cp libcavacore.a $out/lib/
      cp $src/cavacore.h $out/include/cava/
      cat > $out/lib/pkgconfig/cava.pc << EOF
Name: cava
Description: cavacore audio visualizer library
Version: 0.10.7
Libs: -L$out/lib -lcavacore -lfftw3
Cflags: -I$out/include
EOF
    '';
  };
in stdenv.mkDerivation {
  pname = "clavis-shell";
  version = "0.2.0-unstable";

  src = fetchFromGitHub {
    owner = "StatIndet";
    repo = "quickshell";
    rev = "b2b3bdea0b9687093c6aa761d9a59baa84def6ad";
    hash = "sha256-DhWZ+q6sotRFQQkiBjFAj90JcNY5ZyqR6nVZIIm337I=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
    qt6.qttools
    git
    patchelf
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtnetworkauth
    qt6.qtshadertools
    qt6.qt5compat
    qt6.qtmultimedia
    kdePackages.qtkeychain
    kdePackages.qtlottie
    pipewire
    fftw
    cavacore
  ];

  patchPhase = ''
    runHook prePatch
    substituteInPlace core/plugin/m3shapes/CMakeLists.txt \
      --replace-fail \
      'set_target_properties(M3Shapes PROPERTIES CXX_EXTENSIONS OFF)' \
      'set_target_properties(M3Shapes PROPERTIES CXX_EXTENSIONS OFF LIBRARY_OUTPUT_DIRECTORY ''${CLAVIS_QML_BUILD_DIR}/M3Shapes)'
    runHook postPatch
  '';

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DBUILD_TESTING=OFF"
    "-DCMAKE_SKIP_BUILD_RPATH=ON"
    "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON"
    "-DCMAKE_EXE_LINKER_FLAGS=-lfftw3"
    "-DCMAKE_SHARED_LINKER_FLAGS=-lfftw3"
  ];

  postFixup = ''
    find $out/lib/qt6/qml -name "*.so" | while read -r f; do
      old=$(patchelf --print-rpath "$f" 2>/dev/null || true)
      clean=$(printf '%s' "$old" | tr ':' '\n' | grep -v '^/build' | grep -v '^$' | paste -sd: -)
      if [ -n "$clean" ]; then
        patchelf --set-rpath '$ORIGIN'":$clean" "$f" || true
      else
        patchelf --set-rpath '$ORIGIN' "$f" || true
      fi
    done

    mkdir -p $out/bin
    cat > $out/bin/clavis-shell << WRAPEOF
#!/bin/sh
export QML_IMPORT_PATH="$out/lib/qt6/qml:${qt6.qt5compat}/lib/qt-6/qml:${kdePackages.qtlottie}/lib/qt-6/qml"
export LD_LIBRARY_PATH="${kdePackages.qtkeychain}/lib:${fftw}/lib:\$LD_LIBRARY_PATH"
exec quickshell -p "$out/etc/xdg/quickshell/clavis/shell.qml" "\$@"
WRAPEOF
    chmod +x $out/bin/clavis-shell
  '';

  meta = with lib; {
    description = "ClavisShell — quickshell config with niri C++ plugins";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
