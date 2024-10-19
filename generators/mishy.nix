{ config, ... }:
{
  # sops.secrets = {
  #   "mishy_ritiek_hashed_password" = {};
  # };
  #
  # users.users.ritiek.hashedPasswordFile = config.sops.secrets."mishy_ritiek_hashed_password".path;
  users.users.ritiek.password = "";
}
