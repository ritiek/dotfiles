{ pkgs, config, ... }:
{
  home.packages = with pkgs; [
    glava
  ];

  # Generate default configuration.
  home.activation.glava = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.glava}/bin/glava -C
  '';

  # Override configuration.
  home.file.glava = {
    source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_config/glava/bars.glsl;
    target = "${config.home.homeDirectory}/.config/glava/bars.glsl";
  };
}
