{
  lib,
  stdenv,
  python3,
  python3Packages,
  fetchurl,
  autoPatchelfHook,
  zlib,
  ffmpeg,
  makeWrapper,
}:

let
  # moonshine-voice 0.0.62 — manylinux_2_34 aarch64 wheel.
  # Contains libmoonshine.so (ONNX Runtime-based native library) which
  # autoPatchelfHook rewrites so the .so finds libstdc++ and libz at their
  # Nix store paths (no LD_LIBRARY_PATH needed at runtime).
  moonshine-voice = python3Packages.buildPythonPackage rec {
    pname   = "moonshine-voice";
    version = "0.0.62";
    format  = "wheel";

    src = fetchurl {
      url    = "https://files.pythonhosted.org/packages/c5/6a/956ce3f5a4167a56e608e70e4add670c252a7c6eae0b85efb3e0fa44590e/moonshine_voice-0.0.62-py3-none-manylinux_2_34_aarch64.whl";
      sha256 = "01qs5y2qjkx4zzbvgmch5mmgflr2dbfb93hj0vwn24l08kjd7anm";
    };

    nativeBuildInputs = [ autoPatchelfHook ];

    # libstdc++ for libmoonshine.so; zlib for ONNX Runtime inside the wheel.
    buildInputs = [ stdenv.cc.cc.lib zlib ];

    propagatedBuildInputs = with python3Packages; [
      filelock
      numpy
      platformdirs
      requests
      sounddevice
      tqdm
    ];

    # Binary wheel — no Python build step, no test suite to run.
    doCheck = false;

    meta = {
      description = "Fast, accurate, on-device AI library for voice applications (Moonshine)";
      homepage    = "https://github.com/moonshine-ai/moonshine";
      license     = lib.licenses.mit;
      platforms   = [ "aarch64-linux" ];
    };
  };

  pythonEnv = python3.withPackages (ps: [
    moonshine-voice
    ps.fastapi
    ps.uvicorn
    ps.python-multipart
    ps.numpy
  ]);

in
stdenv.mkDerivation {
  pname   = "moonshine-stt-server";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm644 server.py $out/lib/moonshine-stt-server/server.py
    makeWrapper ${pythonEnv}/bin/python $out/bin/moonshine-stt-server \
      --add-flags "$out/lib/moonshine-stt-server/server.py" \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg ]}
    runHook postInstall
  '';

  meta = {
    description = "OpenAI-compatible /v1/audio/transcriptions server backed by Moonshine TINY";
    license     = lib.licenses.mit;
    platforms   = [ "aarch64-linux" ];
    mainProgram = "moonshine-stt-server";
  };
}
