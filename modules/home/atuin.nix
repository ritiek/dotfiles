{
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    daemon.enable = true;
    settings = {
      sync_address = "http://pilab.lion-zebra.ts.net:7235";
      sync_frequency = 0;
      auto_sync = true;
    };
  };
}
