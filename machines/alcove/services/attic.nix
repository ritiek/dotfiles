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
      # storage.path deliberately kept OUTSIDE /var/lib/atticd (the default
      # StateDirectory): with ProtectSystem=strict, systemd presents
      # StateDirectory content through an idmapped bind-mount regardless of
      # DynamicUser/static User=, so any pre-existing (migrated) storage
      # content never matches the process's UID as seen through that mount —
      # "Permission denied" reading anything atticd didn't create itself this
      # boot (systemd upstream doesn't support pre-populating a StateDirectory:
      # https://github.com/systemd/systemd/issues/16060). A path outside
      # StateDirectory instead gets a plain ReadWritePaths bind-mount (see
      # upstream atticd.nix's `isDefaultStateDirectory` check), which respects
      # classic host UID ownership with no idmapping involved.
      storage = {
        type = "local";
        path = "/var/lib/atticd-storage";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/atticd-storage 0750 atticd atticd - -"
  ];

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
  #
  # Static (non-Dynamic) user instead of upstream's default DynamicUser=true:
  # modern systemd presents DynamicUser+StateDirectory content through an
  # idmapped bind-mount, so pre-existing (migrated) storage files never match
  # the process's UID as seen through that mount, however they're chown'd on
  # the host — "Permission denied" reading anything atticd didn't create
  # itself this boot (systemd upstream doesn't support pre-populating a
  # DynamicUser StateDirectory: https://github.com/systemd/systemd/issues/16060).
  # A static user sidesteps idmapping entirely: plain classic ownership.
  users.users.atticd = {
    isSystemUser = true;
    group = "atticd";
    description = "atticd binary cache server";
  };
  users.groups.atticd = {};

  systemd.services.atticd = {
    after = [ "postgresql.service" "postgresql-setup.service" ];
    requires = [ "postgresql.service" "postgresql-setup.service" ];
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "atticd";
      Group = "atticd";
    };
  };
}
