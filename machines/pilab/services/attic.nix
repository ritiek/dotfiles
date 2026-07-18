{ config, pkgs, lib, ... }:
{
  sops.secrets."atticd.env" = {};

  environment.systemPackages = with pkgs; [
    attic-client
  ];

  services.atticd = {
    enable = true;
    environmentFile = config.sops.secrets."atticd.env".path;
    settings = {
      listen = "[::]:7080";
      compression = {
        type = "zstd";
        level = 3;
      };
      database = {
        # PostgreSQL (not SQLite): SQLite serializes all writers, so concurrent
        # uploads fail instantly with SQLITE_BUSY ("database is locked").
        # Postgres (MVCC) handles real concurrent writers. Peer auth over the
        # local socket — atticd runs as system user "atticd", which maps to the
        # postgres role of the same name; no password/secret needed.
        url = "postgres:///atticd?host=/run/postgresql";
      };
      # Disable in-process garbage collection. atticd runs a GC pass on every
      # startup (and atticd restarts on udev events / rebuilds). Run GC manually
      # instead via `atticd --mode garbage-collector-once`.
      garbage-collection.interval = "0s";
      storage = {
        type = "local";
        path = config.fileSystems.nix-binary-cache.mountPoint;
      };
    };
  };

  # Disable PrivateUsers to allow access to root-owned mount point
  # while maintaining other security hardening features.
  systemd.services.atticd.serviceConfig.PrivateUsers = lib.mkForce false;

  # PostgreSQL backend for atticd (replaces SQLite). Peer auth: the "atticd"
  # role is owned by the same-named system user atticd runs as.
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "atticd" ];
    ensureUsers = [
      {
        name = "atticd";
        ensureDBOwnership = true;
      }
    ];
  };

  # atticd must not start before its database is up AND the atticd role/db have
  # been created by postgresql-setup (otherwise migrations fail with
  # 'role "atticd" does not exist').
  systemd.services.atticd = {
    after = [ "postgresql.service" "postgresql-setup.service" ];
    requires = [ "postgresql.service" "postgresql-setup.service" ];
  };

  fileSystems.nix-binary-cache = {
    mountPoint = "/media/${config.fileSystems.nix-binary-cache.label}";
    device = "/dev/disk/by-label/${config.fileSystems.nix-binary-cache.label}";
    fsType = "ext4";
    label = "NIX_BINARY_CACHE";
    autoResize = true;
    options = [
      "noatime"
      "noauto"
      "nofail"
      "x-systemd.automount"
      "x-systemd.mount-timeout=5s"
    ];
  };


  # Set world-writable permissions for the mount point
  # Required because DynamicUser creates the atticd group at runtime,
  # so we can't use group-based permissions in tmpfiles rules.
  systemd.tmpfiles.rules = [
    "d ${config.fileSystems.nix-binary-cache.mountPoint} 0777 root root - -"
  ];

  services.udev.extraRules = ''
    # Restart atticd whenever storage is inserted to let atticd re-lookup database.
    # Allows for hot-swapping between multiple Nix binary cache storage drives.
    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="${config.fileSystems.nix-binary-cache.label}", ENV{ID_FS_TYPE}!="", RUN+="${pkgs.systemd}/bin/systemctl restart atticd.service"

    # Stop atticd when storage is removed to free up system resources.
    ACTION=="remove", SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="${config.fileSystems.nix-binary-cache.label}", ENV{ID_FS_TYPE}!="", RUN+="${pkgs.systemd}/bin/systemctl stop atticd.service"
  '';
}
