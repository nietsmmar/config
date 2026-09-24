{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  glib,
  libGL,
  libice,
  libsm,
  libusb1,
  libx11,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxtst,
  libxcb,
  libxkbcommon,
  nspr,
  nss,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "qsync";
  # 1.0.12.2202 hangs at full CPU while creating folder pairs on Linux.
  # Keep the preceding release until QNAP publishes a fixed Linux client.
  version = "1.0.11.0509";

  src = fetchurl {
    url = "https://download.qnap.com/Storage/Utility/QNAPQsyncClientUbuntux64-${finalAttrs.version}.deb";
    hash = "sha256-o9YqruA1Vrp6YtJDBfQXbZYtZxhBrTGIe8+anEWrkFI=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    cups
    dbus
    expat
    fontconfig
    freetype
    glib
    libGL
    libice
    libsm
    libusb1
    libx11
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxtst
    libxcb
    libxkbcommon
    nspr
    nss
    stdenv.cc.cc.lib
    zlib
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/qsync" "$out/bin" "$out/share/applications" "$out/share/pixmaps"
    cp -a usr/local/bin/QNAP/QsyncClient/. "$out/lib/qsync/"
    cp -a usr/local/lib/QNAP/QsyncClient/. "$out/lib/qsync/"
    cp usr/share/pixmaps/Qsync.png "$out/share/pixmaps/"

    # QNAP ships plugins for several environments. This host runs X11 and the
    # client uses its bundled SQLite driver, so omit unrelated plugins whose
    # Ubuntu-only dependencies are not needed at runtime.
    rm -rf "$out/lib/qsync/platforminputcontexts"
    rm -f "$out/lib/qsync/sqldrivers/libqsqlodbc.so"
    rm -f "$out/lib/qsync/sqldrivers/libqsqlpsql.so"
    find "$out/lib/qsync/platforms" -type f ! -name libqxcb.so -delete

    substitute usr/share/applications/QNAPQsyncClient.desktop \
      "$out/share/applications/QNAPQsyncClient.desktop" \
      --replace-fail /usr/local/bin/QNAP/QsyncClient/Qsync.sh "$out/bin/qsync" \
      --replace-fail /usr/share/pixmaps/Qsync.png "$out/share/pixmaps/Qsync.png"

    substituteInPlace "$out/lib/qsync/"*.sh \
      --replace-warn /usr/local/bin/QNAP/QsyncClient "$out/lib/qsync" \
      --replace-warn /usr/local/lib/QNAP/QsyncClient "$out/lib/qsync"

    makeWrapper "$out/lib/qsync/Qsync" "$out/bin/qsync" \
      --run 'ulimit -n 4096' \
      --set QT_PLUGIN_PATH "$out/lib/qsync" \
      --set QT_QPA_PLATFORM_PLUGIN_PATH "$out/lib/qsync/platforms" \
      --prefix LD_LIBRARY_PATH : "$out/lib/qsync"

    runHook postInstall
  '';

  meta = {
    description = "QNAP Qsync file synchronization client";
    homepage = "https://www.qnap.com/en/utilities/essentials?utility=qsync";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "qsync";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
