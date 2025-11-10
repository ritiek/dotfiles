{
  services.shpool = {
    enable = true;
    systemd = true;
    settings = {
      keybinding = [
        {
          action = "detach";
          binding = "Ctrl-a d";
        }
      ];
      session_restore_mode = {
        lines = 1000;
      };
    };
  };
}
