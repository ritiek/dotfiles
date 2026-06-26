{ config, ... }:
{
  sops = {
    # Image/installer variants (different hostName, same secrets) reuse their
    # base host's secrets file rather than a nonexistent per-variant directory.
    defaultSopsFile =
      let
        baseHost =
          if config.networking.hostName == "mishy-usb" then "mishy"
          else if config.networking.hostName == "pilab-sd" || config.networking.hostName == "pilab-minimal-sd" then "pilab"
          else config.networking.hostName;
      in
      ./../machines/${baseHost}/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };
}
