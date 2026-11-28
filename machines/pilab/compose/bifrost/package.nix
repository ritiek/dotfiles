# nixpkgs' bifrost recipe (pkgs/by-name/bi/bifrost), bumped to the version the
# stack runs and patched to keep upstream model metadata in /v1/models, to
# drop MCP output schemas the spec doesn't allow and to send Copilot x-initiator.
# shortcut: model-metadata.patch covers maximhq/bifrost#8914 (open PR #9201) plus
# provider display names; drop the metadata part once that PR ships.
{
  lib,
  buildGo127Module,
  buildNpmPackage,
  fetchFromGitHub,
  pkg-config,
  sqlite,
}:

let
  version = "2.7.0";

  src = fetchFromGitHub {
    owner = "maximhq";
    repo = "bifrost";
    tag = "transports/v${version}";
    hash = "sha256-kmN3bV5QX1tClb7p7qz6UNOydzBC0tcRZLeNAs0Dt/s=";
  };

  # The patch only touches Go code, so the UI is built from the plain source.
  ui = buildNpmPackage {
    pname = "bifrost-ui";
    inherit version src;
    sourceRoot = "${src.name}/ui";

    npmDepsHash = "sha256-JtaSXBfz7toZ8gF9Jjq5iveV/b5obQNhA9VvjyvDky0=";

    # `build-enterprise` is `vite build` plus a tsc type-check that writes nothing
    # but costs the Pi a lot of time and memory.
    buildPhase = ''
      runHook preBuild
      npx vite build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/ui"
      cp -R --no-preserve=all out/. "$out/ui/"
      runHook postInstall
    '';
  };
in
buildGo127Module {
  pname = "bifrost";
  inherit version src;

  patches = [
    ./model-metadata.patch
    # The gateway passes on GitHub MCP output schemas typed ["null","object"],
    # which make Hermes (the Python MCP SDK) drop every tool from /mcp.
    ./mcp-output-schema.patch
    # x-initiator per request for GitHub Copilot, so tool-call follow-ups
    # aren't billed as premium requests.
    ./copilot-initiator.patch
    # OpenAPI (in-process) MCP tools called from a /mcp request on protocol
    # 2026-07-28 were checked against that request's Mcp-Method/Mcp-Name headers
    # and refused ("header mismatch").
    ./mcp-inprocess-headers.patch
    # A provider's retry hint reaches the client as the standard Retry-After
    # header, not only as the opt-in x-bifrost-retry-after-ms.
    ./retry-after-header.patch
  ];

  modRoot = "transports";
  subPackages = [ "bifrost-http" ];
  # A vendor/ dir would hold a copy of the sibling modules, patched core included,
  # frozen under vendorHash: editing the patch would silently build the old copy.
  # The module proxy holds only third-party code; core is read from the source tree.
  proxyVendor = true;
  vendorHash = "sha256-lBDdpQjKhS/A62lELx44kPqC5jbUEOm1cACym44l+kg=";

  doCheck = false;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ sqlite ];

  env.CGO_ENABLED = "1";

  # Bifrost asks for Go 1.27.4; nixpkgs has 1.27.3, a bugfix release apart.
  # The transports module points at its sibling modules with `replace`
  # directives that buildGoModule needs spelled out against the source tree.
  postPatch = ''
    find . -name go.mod -exec sed -i 's/^go 1\.27\.4$/go 1.27.3/' {} +
    cat >> transports/go.mod <<'EOF'

    replace github.com/maximhq/bifrost/core => ../core
    replace github.com/maximhq/bifrost/framework => ../framework
    replace github.com/maximhq/bifrost/plugins/compat => ../plugins/compat
    replace github.com/maximhq/bifrost/plugins/governance => ../plugins/governance
    replace github.com/maximhq/bifrost/plugins/logging => ../plugins/logging
    replace github.com/maximhq/bifrost/plugins/maxim => ../plugins/maxim
    replace github.com/maximhq/bifrost/plugins/mocker => ../plugins/mocker
    replace github.com/maximhq/bifrost/plugins/modelcatalogresolver => ../plugins/modelcatalogresolver
    replace github.com/maximhq/bifrost/plugins/otel => ../plugins/otel
    replace github.com/maximhq/bifrost/plugins/prompts => ../plugins/prompts
    replace github.com/maximhq/bifrost/plugins/routing => ../plugins/routing
    replace github.com/maximhq/bifrost/plugins/semanticcache => ../plugins/semanticcache
    replace github.com/maximhq/bifrost/plugins/telemetry => ../plugins/telemetry
    EOF
  '';

  # The module fetcher needs postPatch but not the UI copy in preBuild.
  overrideModAttrs = _: _: {
    preBuild = "";
  };

  # Provide the pre-built UI for //go:embed all:ui inside bifrost-http.
  preBuild = ''
    rm -rf bifrost-http/ui
    mkdir -p bifrost-http/ui
    cp -R --no-preserve=all ${ui}/ui/. bifrost-http/ui/
  '';

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
  ];

  passthru = { inherit ui; };

  meta = {
    description = "High-performance LLM gateway with native MCP support";
    homepage = "https://github.com/maximhq/bifrost";
    license = lib.licenses.asl20;
    mainProgram = "bifrost-http";
    platforms = lib.platforms.linux;
  };
}
