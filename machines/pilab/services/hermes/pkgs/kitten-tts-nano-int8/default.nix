{
  stdenv,
  lib,
  fetchurl,
}:

let
  version = "0.2.2";

  models = fetchurl {
    url = "https://github.com/second-state/kitten_tts_rs/releases/download/v${version}/kitten-tts-models.tar.gz";
    hash = "sha256-rdVn4OKpCO8oRTwQuwQap7fDCZn7LcznxZ+kXC1t0U8=";
  };
in
stdenv.mkDerivation {
  pname = "kitten-tts-nano-int8";
  inherit version;

  src = models;

  sourceRoot = ".";

  # The tarball ships every model variant (~174MB). Keep only nano-int8
  # (25MB), the chosen default. Output is the model dir itself so consumers
  # point the server straight at $out.
  installPhase = ''
    runHook preInstall
    cp -r models/kitten-tts-nano-int8 $out
    runHook postInstall
  '';

  meta = {
    description = "KittenTTS nano-int8 model weights (for kitten-tts-rs)";
    homepage = "https://github.com/second-state/kitten_tts_rs";
    license = lib.licenses.asl20;
  };
}
