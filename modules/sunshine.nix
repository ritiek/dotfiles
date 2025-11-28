{ inputs, config, ... }:
{
  services.sunshine = {
    enable = true;
    autoStart = false;
    capSysAdmin = true;
    settings = {
      sunshine_name = config.networking.hostName;
    };
  };

  # imports = [
  #   inputs.apollo-flake.nixosModules.x86_64-linux.default
  # ];
  #
  # services.apollo = {
  #   enable = true;
  #   package = inputs.apollo-flake.packages.x86_64-linux.default;
  #   capSysAdmin = true;
  #   openFirewall = true;
  #   applications = {
  #     apps = [
  #       {
  #         name = "Monitor";
  #         exclude-global-prep-cmd = "false";
  #         auto-detach = "true";
  #       }
  #     ];
  #   };
  # };
}
