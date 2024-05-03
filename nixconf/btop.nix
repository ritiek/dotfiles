{ pkgs, ... }:
{
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "adapta";
      vim_keys = true;
      cpu_graph_lower = "iowait";
      proc_sorting = "memory";
    };
  };
}
