{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  patchelfUnstable,
  wrapGAppsHook3,
  alsa-lib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "betterbird";
  version = "140.5.0esr-bb14";

  src = fetchurl {
    url = "https://www.betterbird.eu/downloads/LinuxArchive/betterbird-140.5.0esr-bb14.en-US.linux-x86_64.tar.xz";
    hash = "sha256-++GMTnQ8b2oa5JWWQMzO80R++dC41NrgcaWvOcAd5sY=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    patchelfUnstable
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
  ];

  # Thunderbird uses "relrhack" to manually process relocations from a fixed offset
  patchelfFlags = [ "--no-clobber-old-sections" ];

  strictDeps = true;

  postPatch = ''
    # Don't download updates from Mozilla directly
    echo 'pref("app.update.auto", "false");' >> defaults/pref/channel-prefs.js
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$prefix/usr/lib/betterbird-bin-${finalAttrs.version}"
    cp -r * "$prefix/usr/lib/betterbird-bin-${finalAttrs.version}"

    mkdir -p "$out/bin"
    ln -s "$prefix/usr/lib/betterbird-bin-${finalAttrs.version}/betterbird" "$out/bin/"

    # wrapThunderbird expects "$out/lib" instead of "$out/usr/lib"
    ln -s "$out/usr/lib" "$out/lib"

    runHook postInstall
  '';

  meta = {
    changelog = "https://www.betterbird.net/en-US/betterbird/${finalAttrs.version}/releasenotes/";
    description = "Betterbird is a fine-tuned version of Mozilla Thunderbird, Thunderbird on steroids, if you will.";
    homepage = "https://www.betterbird.eu";
    mainProgram = "betterbird";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.mpl20;
    maintainers = with lib.maintainers; [ ];
    platforms = [ "x86_64-linux" ];
  };
})
