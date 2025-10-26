{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "*.lion-zebra.ts.net" = {
        extraOptions = {
          PubkeyAuthentication = "unbound";
        };
      };
    };
  };
  services.ssh-agent = {
    enable = true;
  };
}
