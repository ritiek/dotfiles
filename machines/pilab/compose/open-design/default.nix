# Hand-written in the compose2nix style used by sibling services in this
# directory, but without a sops-managed stack.env: OpenDesign needs no
# secret here because OD_DISABLE_API_AUTH=1 is set below (see rationale).

{ pkgs, lib, config, homelabMediaPath, ... }:

{
  # Runtime
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };
  virtualisation.oci-containers.backend = "docker";

  # Containers
  virtualisation.oci-containers.containers."open-design" = {
    # Built locally from ghcr.io/nexu-io/od:latest + libc6-compat (see the
    # open-design-image-build service below) so the glibc-linked
    # vela-cli-linux-arm64 binary can actually run on this Alpine image.
    image = "open-design-local:latest";
    environment = {
      NODE_ENV = "production";
      NODE_OPTIONS = "--max-old-space-size=192";
      OD_BIND_HOST = "0.0.0.0";
      OD_PORT = "7456";
      OD_WEB_PORT = "7456";
      # Browser UI is served from this origin; the daemon rejects any
      # cross-origin /api call whose Origin header isn't listed here.
      OD_ALLOWED_ORIGINS = "http://pilab.lion-zebra.ts.net:7456";
      # od mcp's stdio client has no code path to send an Authorization
      # header, so an enforced OD_API_TOKEN would 401 every MCP tool call
      # from other hosts. Tailscale (this host is only reachable via
      # pilab.lion-zebra.ts.net) is the trust boundary instead, matching
      # upstream's own guidance for deployments behind an already-trusted
      # private network.
      OD_DISABLE_API_AUTH = "1";
      # "vela" (AMR) drives OpenDesign's own hosted generation runtime
      # (start_run/Cloud sign-in). It ships as the @powerformer/vela-cli
      # npm package, not inside the od image, and is installed into the
      # open-design-vela volume by the oneshot service below. Prepend it
      # to the image's normal Alpine PATH rather than replacing it.
      PATH = "/mnt/host-vela/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";
      VELA_BIN = "/mnt/host-vela/bin/vela";
    };
    volumes = [
      "${homelabMediaPath}/services/open-design/data:/app/.od"
      "open-design-vela:/mnt/host-vela:ro"
    ];
    ports = [
      "7456:7456/tcp"
    ];
    log-driver = "journald";
    autoStart = false;
    # dependsOn only wires up other oci-containers.containers entries;
    # the image-build step is a plain systemd oneshot, so it's added to
    # after/requires below instead.
    dependsOn = [
      "open-design-vela-install"
    ];
    extraOptions = [
      "--network-alias=open-design"
      "--network=open-design_open-design-net"
    ];
    labels = {
      "homepage.description" = "AI design tool (MCP daemon)";
      "homepage.group" = "Services";
      "homepage.href" = "http://pilab.lion-zebra.ts.net:7456";
      "homepage.icon" = "open-design";
      "homepage.name" = "OpenDesign";
    };
  };
  systemd.services."docker-open-design" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-open-design_open-design-net.service"
      "docker-open-design-vela-install.service"
      "open-design-image-build.service"
    ];
    requires = [
      "docker-network-open-design_open-design-net.service"
      "docker-open-design-vela-install.service"
      "open-design-image-build.service"
    ];
    unitConfig.RequiresMountsFor = [
      "${homelabMediaPath}/services/open-design/data"
    ];
  };

  # One-shot: build open-design-local:latest from the upstream od image plus
  # libc6-compat. The upstream ghcr.io/nexu-io/od image is plain Alpine
  # (musl); vela-cli's arm64/x64 native binaries are glibc-linked, so they
  # fail with ENOENT (missing /lib/ld-linux-*.so) without this. Matches
  # upstream's own deploy/Dockerfile.local approach for mounted host CLIs.
  systemd.services."open-design-image-build" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker build -t open-design-local:latest - <<'EOF'
      FROM ghcr.io/nexu-io/od:latest
      USER root
      RUN apk add --no-cache libc6-compat
      USER open-design
      EOF
    '';
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
  };

  # One-shot: install the vela CLI into a named volume so it can be
  # mounted read-only into the open-design container (see PATH/VELA_BIN
  # above). Re-running is harmless and cheap (npm no-ops if unchanged);
  # bump the image tag or rerun manually to pick up a newer vela-cli.
  virtualisation.oci-containers.containers."open-design-vela-install" = {
    image = "node:24-alpine";
    entrypoint = "sh";
    cmd = [
      "-c"
      "npm install --global --prefix /vela @powerformer/vela-cli"
    ];
    volumes = [
      "open-design-vela:/vela"
    ];
    log-driver = "journald";
    autoStart = false;
    extraOptions = [
      "--network-alias=open-design-vela-install"
      "--network=open-design_open-design-net"
    ];
  };
  systemd.services."docker-open-design-vela-install" = {
    serviceConfig = {
      Type = lib.mkOverride 90 "oneshot";
      RemainAfterExit = lib.mkOverride 90 true;
      # npm registry fetch can take a while on first run.
      TimeoutStartSec = lib.mkOverride 90 "300s";
    };
    after = [
      "docker-network-open-design_open-design-net.service"
    ];
    requires = [
      "docker-network-open-design_open-design-net.service"
    ];
  };

  # Networks
  systemd.services."docker-network-open-design_open-design-net" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "${pkgs.docker}/bin/docker network rm -f open-design_open-design-net";
    };
    script = ''
      docker network inspect open-design_open-design-net || docker network create open-design_open-design-net --driver=bridge
    '';
    partOf = [ "docker-compose-open-design-root.target" ];
    wantedBy = [ "docker-compose-open-design-root.target" ];
  };

  # Root service
  systemd.targets."docker-compose-open-design-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
  };
}
