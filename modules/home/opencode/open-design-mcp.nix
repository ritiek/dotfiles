# OpenDesign's `od mcp` stdio client, lifted out of the daemon image so it
# runs on plain nodejs without a local Docker daemon. It is pure JS that
# talks HTTP to the daemon on pilab; the native/media deps are dropped.
# Used by OpenCode and by Bifrost's MCP gateway (machines/pilab/compose/bifrost).
{ dockerTools, runCommand, jq, writeShellScript, nodejs_24, stdenv }:

let
  # ponytail: pinned digest of 0.27.1, bump with nix-prefetch-docker together
  # with the pilab daemon's FROM tag (machines/pilab/compose/open-design).
  image = dockerTools.pullImage {
    imageName = "ghcr.io/nexu-io/od";
    imageDigest = "sha256:e60aec9fb7e07af9f11de58eff62a546c82421d3a24aa57a353b4c2808a1d85c";
    hash = {
      x86_64-linux = "sha256-cg4NhXsfl+s7v/N7wz2d8t2s36fpmOJCEuSFF8U/VG4=";
      aarch64-linux = "sha256-MnuTqGLXGLq+18VwZyPKCtEvTBEyTKx2T6TtvV0c3dA=";
    }.${stdenv.hostPlatform.system};
    finalImageTag = "latest";
  };
  daemon = runCommand "open-design-daemon" { nativeBuildInputs = [ jq ]; } ''
    mkdir image $out
    tar -xf ${image} -C image
    for layer in $(jq -r '.[0].Layers[]' image/manifest.json); do
      tar -xf "image/$layer" -C $out --strip-components=3 app/apps/daemon 2>/dev/null || true
    done
    cd $out/node_modules/.pnpm
    rm -rf onnxruntime-node@* @ffmpeg-installer+* node-pty@* @img+sharp* esbuild@* @esbuild+*
    test -f $out/dist/cli.js
  '';
in
writeShellScript "open-design-mcp" ''
  # od mcp exits after 30 min idle by default and opencode doesn't respawn it.
  export OD_MCP_STDIO_IDLE_EXIT_MS=0
  exec ${nodejs_24}/bin/node ${daemon}/dist/cli.js mcp "$@"
''
