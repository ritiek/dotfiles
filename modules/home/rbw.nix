{ pkgs, inputs, ... }:
{
  programs.rbw = {
    enable = true;
    package = pkgs.rbw.overrideAttrs (old: {
      src = inputs.rbw;
      # XXX: Running tests causes test run timeout failures on Pi5 although
      #      it works fine on my lappy. Actually, this doesn't to stop the
      #      tests from running on RPi5 either later when I tried to rebuild.
      # doCheck = false;
    });
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
