{
  programs.opencode = {
    enable = true;
    settings = {
      model = "claude-sonnet-4-5-20250929";
      theme = "system";
      tui.scroll_speed = 5;
      autoupdate = false;
      # mcp.context7 = {
      #   enabled = true;
      #   type = "remote";
      #   url = "https://mcp.context7.com/mcp";
      #   headers.CONTEXT7_API_KEY = "INSERT_COIN";
      # };
    };
  };
}
