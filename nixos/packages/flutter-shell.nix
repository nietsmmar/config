# ~/dev/config/nixos/packages/flutter-shell.nix
# This file defines the development shell for the flutter project.
{ pkgs }:

pkgs.mkShell {
  # These are the packages that will be available in the shell
  buildInputs = with pkgs; [
    clang
    cmake
    ninja
    binutils # provides ld.bfd (LLD 21 is incompatible with Flutter's engine .so)
    pkg-config
    gtk3
    webkitgtk_4_1
    xorg.libX11
    util-linux.dev
    xorg.libXdmcp
    xorg.libXtst
    sysprof
    libepoxy
    fontconfig
    android-studio
    pre-commit
    poppler-utils #for pdf manipulation when uploading lessons

    # Required by audioplayers_linux
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
  ];

  shellHook = ''
    # Force GNU ld.bfd — LLD 21 rejects Flutter's pre-compiled libflutter_linux_gtk.so.
    # Always run `flutter clean` after changing this so cmake regenerates its cache.
    export LDFLAGS="-fuse-ld=bfd ''${LDFLAGS:-}"

    # sysprof-capture-4 is a private dep of glib-2.0 — provide both outputs
    export PKG_CONFIG_PATH=${pkgs.sysprof.dev}/lib/pkgconfig:${pkgs.sysprof}/lib/pkgconfig:${pkgs.gst_all_1.gstreamer.dev}/lib/pkgconfig:${pkgs.gst_all_1.gst-plugins-base.dev}/lib/pkgconfig:$PKG_CONFIG_PATH

    export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
      pkgs.libepoxy
      pkgs.fontconfig
      pkgs.gst_all_1.gstreamer
      pkgs.gst_all_1.gst-plugins-base
      pkgs.gst_all_1.gst-plugins-good
      pkgs.gst_all_1.gst-plugins-bad
      pkgs.gst_all_1.gst-plugins-ugly
      pkgs.gst_all_1.gst-libav
    ]}:$LD_LIBRARY_PATH
    export GST_PLUGIN_SYSTEM_PATH_1_0=${pkgs.gst_all_1.gstreamer.out}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-bad}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-ugly}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-libav}/lib/gstreamer-1.0
    export GST_PLUGIN_PATH=${pkgs.gst_all_1.gstreamer.out}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-bad}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-ugly}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-libav}/lib/gstreamer-1.0
    export GST_PLUGIN_SCANNER=${pkgs.gst_all_1.gstreamer.out}/libexec/gstreamer-1.0/gst-plugin-scanner
    export GST_REGISTRY=$HOME/.cache/gstreamer-1.0/registry.bin
  '';
}
