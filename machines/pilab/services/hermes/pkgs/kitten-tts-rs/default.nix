{
  stdenv,
  lib,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "0.2.2";

  binary = fetchurl {
    url = "https://github.com/second-state/kitten_tts_rs/releases/download/v${version}/kitten-tts-aarch64-linux.tar.gz";
    hash = "sha256-R5XUZQcHtDe4u6TvwAeiGkntGUx7ZyTWtgZWrVTu8zM=";
  };
in
stdenv.mkDerivation {
  pname = "kitten-tts-rs";
  inherit version;

  src = binary;

  # Prebuilt aarch64-linux binaries (per project decision: prebuilt only, no
  # source/buildRustPackage fallback). autoPatchelfHook rewrites the ELF
  # interpreter + RPATH so the release binaries run on NixOS.
  nativeBuildInputs = [ autoPatchelfHook ];

  # libstdc++ / libgcc_s for the Rust binary's C++ runtime deps.
  buildInputs = [ stdenv.cc.cc.lib ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 kitten-tts-aarch64-linux/kitten-tts        $out/bin/kitten-tts
    install -Dm755 kitten-tts-aarch64-linux/kitten-tts-server $out/bin/kitten-tts-server
    runHook postInstall
  '';

  meta = {
    description = "Rust port of KittenTTS (CLI + OpenAI-compatible server), prebuilt aarch64-linux";
    homepage = "https://github.com/second-state/kitten_tts_rs";
    license = lib.licenses.asl20;
    platforms = [ "aarch64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "kitten-tts-server";
  };
}
