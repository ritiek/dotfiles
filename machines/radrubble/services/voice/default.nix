# NPU-accelerated speech for hermes (which runs on pilab):
#   STT: SenseVoice-small (RK3566 RKNN build) via sherpa-onnx, OpenAI-compatible
#        /v1/audio/transcriptions on :7258
#   TTS: Piper en_US-kristin-medium via paroli, decoder on NPU, encoder on CPU,
#        POST /api/v1/synthesise on :7257
#
# The Kristin encoder.onnx/decoder.rknn are not fetchable: they're exported from
# the Piper training checkpoint (mush42/piper streaming branch) and converted
# with paroli's tools/decoder2rknn.py (target_platform rk3566). Copy them along
# with model.json (en_US-kristin-medium.onnx.json) into /var/lib/paroli/kristin.
{ pkgs, lib, ... }:

let
  rknnTag = "https://raw.githubusercontent.com/airockchip/rknn-toolkit2/v2.3.2/rknpu2/runtime/Linux/librknn_api";

  librknnrt = pkgs.stdenv.mkDerivation {
    pname = "librknnrt";
    version = "2.3.2";
    srcs = [
      (pkgs.fetchurl {
        url = "${rknnTag}/aarch64/librknnrt.so";
        hash = "sha256-0x/BnIW4X2CRsr0PavnZYtUmSk5BC/tTZALskrrHOOg=";
      })
      (pkgs.fetchurl {
        url = "${rknnTag}/include/rknn_api.h";
        hash = "sha256-xI4RpvQbRRpf0eStd06mAlLT2U94vumyHqPSGyHeupo=";
      })
    ];
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    installPhase = ''
      set -- $srcs
      install -Dm755 $1 $out/lib/librknnrt.so
      install -Dm644 $2 $out/include/rknn_api.h
    '';
  };

  paroli = pkgs.stdenv.mkDerivation {
    pname = "paroli";
    version = "0-unstable-2026-02-28";
    src = pkgs.fetchFromGitHub {
      owner = "marty1885";
      repo = "paroli";
      rev = "0bf1f9f80acb69c47b0dc3a50a6ed2c302b253ef";
      hash = "sha256-YHGZz45T7wsSuhb+FK1ol9WNOKP5MW3J63O+DYNITf0=";
    };

    # xtensor >= 0.26 moved its headers into subdirectories.
    postPatch = ''
      substituteInPlace piper/*.hpp piper/*.cpp \
        --replace-quiet xtensor/xarray.hpp xtensor/containers/xarray.hpp \
        --replace-quiet xtensor/xadapt.hpp xtensor/containers/xadapt.hpp \
        --replace-quiet xtensor/xview.hpp xtensor/views/xview.hpp \
        --replace-quiet xtensor/xio.hpp xtensor/io/xio.hpp
    '';

    nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config ];
    buildInputs = with pkgs; [
      drogon jsoncpp openssl zlib brotli c-ares libuuid
      fmt spdlog nlohmann_json xtensor xtl
      libopus libopusenc libogg soxr
      onnxruntime piper-phonemize librknnrt
    ];
    cmakeFlags = [
      "-DUSE_RKNN=ON"
      "-DORT_ROOT=${pkgs.onnxruntime}"
      "-DPIPER_PHONEMIZE_ROOT=${pkgs.piper-phonemize}"
    ];
    env.NIX_CFLAGS_COMPILE = "-I${pkgs.onnxruntime.dev}/include/onnxruntime";

    # No install() rules upstream.
    installPhase = ''
      install -Dm755 paroli-server paroli-cli -t $out/bin
    '';
  };

  sttPython = pkgs.python3.withPackages (ps: [
    ps.fastapi
    ps.uvicorn
    ps.python-multipart
    ps.numpy
    (ps.buildPythonPackage {
      pname = "sherpa-onnx";
      version = "1.13.8";
      format = "wheel";
      # RKNN-enabled build from https://k2-fsa.github.io/sherpa/onnx/rk-npu.html
      src = pkgs.fetchurl {
        url = "https://huggingface.co/csukuangfj2/sherpa-onnx-wheels/resolve/main/rknn/1.13.8/sherpa_onnx-1.13.8-cp314-cp314-manylinux_2_27_aarch64.whl";
        hash = "sha256-IDlhtp64kuRuTzebPo1WAE0pxhb8qVFNMgQRT27ONyY=";
      };
      nativeBuildInputs = [ pkgs.autoPatchelfHook ];
      buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.alsa-lib librknnrt ];
      dependencies = [ ps.numpy ];
      doCheck = false;
    })
  ]);

  senseVoice = pkgs.fetchzip {
    url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-rk3566-20-seconds-sense-voice-zh-en-ja-ko-yue-2025-09-09.tar.bz2";
    hash = "sha256-LDykfnAWybYQSVUKWWYLSThcJEI1w7e10kRRGcnnp3M=";
  };
in
{
  systemd.services.sensevoice-stt = {
    description = "SenseVoice STT on the RK3566 NPU (OpenAI-compatible)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = [ pkgs.ffmpeg-headless ];
    environment = {
      STT_MODEL = "${senseVoice}/model.rknn";
      STT_TOKENS = "${senseVoice}/tokens.txt";
      STT_HOST = "0.0.0.0";
      STT_PORT = "7258";
    };
    serviceConfig = {
      ExecStart = "${sttPython}/bin/python ${./stt-server.py}";
      DynamicUser = true;
      SupplementaryGroups = [ "video" "render" ];
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  systemd.services.paroli-tts = {
    description = "Piper (Kristin) TTS via paroli, decoder on the RK3566 NPU";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    unitConfig.ConditionPathExists = "/var/lib/paroli/kristin/decoder.rknn";
    serviceConfig = {
      ExecStart = lib.concatStringsSep " " [
        "${paroli}/bin/paroli-server"
        "--encoder /var/lib/paroli/kristin/encoder.onnx"
        "--decoder /var/lib/paroli/kristin/decoder.rknn"
        "--config /var/lib/paroli/kristin/model.json"
        "--espeak_data ${pkgs.piper-phonemize}/share/espeak-ng-data"
        "--ip 0.0.0.0 --port 7257 --disable-web-ui"
      ];
      DynamicUser = true;
      SupplementaryGroups = [ "video" "render" ];
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 7257 7258 ];
}
