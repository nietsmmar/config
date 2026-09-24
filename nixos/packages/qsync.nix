{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  buildFHSEnv,
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

let
  qsync-unwrapped = stdenv.mkDerivation (finalAttrs: {
    pname = "qsync-unwrapped";
    version = "1.0.12.2202";

    src = fetchurl {
      url = "https://download.qnap.com/Storage/Utility/QNAPQsyncClientUbuntux64-${finalAttrs.version}.deb";
      hash = "sha256-B7hbS8e/E28qUzRZWhhkRTzbdd5TwMpCWmWaAkeOAvg=";
    };

    nativeBuildInputs = [
      autoPatchelfHook
      dpkg
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

      bin_dir="$out/usr/local/bin/QNAP/QsyncClient"
      lib_dir="$out/usr/local/lib/QNAP/QsyncClient"
      mkdir -p "$bin_dir" "$lib_dir" "$out/share/applications" "$out/share/pixmaps"
      cp -a usr/local/bin/QNAP/QsyncClient/. "$bin_dir/"
      cp -a usr/local/lib/QNAP/QsyncClient/. "$lib_dir/"
      cp usr/share/applications/QNAPQsyncClient.desktop "$out/share/applications/"
      cp usr/share/pixmaps/Qsync.png "$out/share/pixmaps/"

      # This host runs X11 and Qsync uses its bundled SQLite driver.
      rm -rf "$bin_dir/platforminputcontexts"
      rm -f "$bin_dir/sqldrivers/libqsqlodbc.so"
      rm -f "$bin_dir/sqldrivers/libqsqlpsql.so"
      find "$bin_dir/platforms" -type f ! -name libqxcb.so -delete

      runHook postInstall
    '';

    meta = {
      license = lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  });
in
buildFHSEnv {
  name = "qsync";

  # The proprietary binary launches helpers through hard-coded /usr/local
  # paths. Keep QNAP's original Ubuntu layout inside a small FHS environment.
  targetPkgs = _pkgs: [ qsync-unwrapped ];
  extraBuildCommands = ''
    mkdir -p "$out/usr/local" "$out/var/lib/dbus"
  '';
  extraBwrapArgs = [
    "--ro-bind ${qsync-unwrapped}/usr/local /usr/local"
    # Qsync's bundled Qt checks this legacy Ubuntu path when generating the
    # encryption key used to store the NAS password.
    "--ro-bind /etc/machine-id /var/lib/dbus/machine-id"
  ];
  runScript = "/usr/local/bin/QNAP/QsyncClient/Qsync.sh";

  extraInstallCommands = ''
    mkdir -p "$out/share/applications" "$out/share/pixmaps"
    substitute ${qsync-unwrapped}/share/applications/QNAPQsyncClient.desktop \
      "$out/share/applications/QNAPQsyncClient.desktop" \
      --replace-fail /usr/local/bin/QNAP/QsyncClient/Qsync.sh "$out/bin/qsync" \
      --replace-fail /usr/share/pixmaps/Qsync.png "$out/share/pixmaps/Qsync.png"
    cp ${qsync-unwrapped}/share/pixmaps/Qsync.png "$out/share/pixmaps/"
  '';

  meta = {
    description = "QNAP Qsync file synchronization client";
    homepage = "https://www.qnap.com/en/utilities/essentials?utility=qsync";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "qsync";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
