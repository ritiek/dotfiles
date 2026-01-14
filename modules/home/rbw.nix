{ pkgs, inputs, ... }:
{
  programs.rbw = {
    enable = true;
    # package = pkgs.rbw.overrideAttrs (old: {
    #   src = inputs.rbw;
    # });
    settings = {
      email = "ritiekmalhotra123@gmail.com";
      # base_url = "https://vaultwarden.clawsiecats.lol";
      base_url = "http://pilab.lion-zebra.ts.net:9446";
      lock_timeout = 300;
      # pinentry = pkgs.pinentry-qt;
      pinentry = pkgs.pinentry-gnome3;
    };
  };
}
