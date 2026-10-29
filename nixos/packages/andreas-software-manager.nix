{
  stdenvNoCC,
  gobject-introspection,
  makeWrapper,
  wrapGAppsHook3,
  gtk3,
  python3,
  nix,
  polkit,
  lib,
}:

stdenvNoCC.mkDerivation {
  pname = "programme-verwalten";
  version = "1.0";
  dontUnpack = true;

  nativeBuildInputs = [
    gobject-introspection
    makeWrapper
    wrapGAppsHook3
  ];
  buildInputs = [ gtk3 ];

  installPhase = ''
    mkdir -p "$out/bin"
    makeWrapper \
      "${python3.withPackages (pythonPackages: [ pythonPackages.pygobject3 ])}/bin/python3" \
      "$out/bin/programme-verwalten" \
      --add-flags "${../apps/andreas-software-gui.py}" \
      --prefix PATH : ${lib.makeBinPath [ nix polkit ]}
  '';
}
