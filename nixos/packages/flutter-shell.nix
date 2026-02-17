# ~/dev/config/nixos/packages/flutter-shell.nix
# This file defines the development shell for the flutter project.
{ system ? builtins.currentSystem }:

let
  pkgs = import <nixpkgs> {
    inherit system;
    config.allowUnfree = true; # Allow unfree packages within this shell
  };
in
pkgs.mkShell {
  # These are the packages that will be available in the shell
  buildInputs = with pkgs; [
    clang
    cmake
    ninja
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
  ];

  shellHook = ''
    export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [ pkgs.libepoxy pkgs.fontconfig ]}:$LD_LIBRARY_PATH
    export PKG_CONFIG_PATH=${pkgs.gst_all_1.gstreamer.dev}/lib/pkgconfig:${pkgs.gst_all_1.gst-plugins-base.dev}/lib/pkgconfig:${pkgs.sysprof.dev}/lib/pkgconfig:$PKG_CONFIG_PATH
  '';
}
