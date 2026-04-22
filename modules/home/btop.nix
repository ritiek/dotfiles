{ pkgs, ... }:
{
  programs.btop = {
    enable = true;
    settings = {
      # color_theme = "adapta";
      color_theme = "dracula";
      vim_keys = true;
      cpu_graph_lower = "iowait";
      proc_sorting = "memory";
      net_auto = false;
    };
  };
}
