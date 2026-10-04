{ pkgs, ... }:
{
  # NOTE: This creates ~/.config/lutris, which makes lutris use it as CONFIG_DIR
  # (games/*.yml, lutris.conf, system.yml) instead of ~/.local/share/lutris.
  # Runner binaries, pga.db, banners etc. still live in ~/.local/share/lutris.
  programs.lutris = {
    enable = true;
    package = pkgs.unstable.lutris;
    extraPackages = with pkgs; [
      # # Bombsquad Game
      # python312
      # SDL2
      # libvorbis
      # libGL
      # openal
      # stdenv.cc.cc
    ];
    # programs.lutris has no extraLibraries option; if needed, override the
    # package instead: pkgs.unstable.lutris.override { extraLibraries = ...; }
    # extraLibraries = pkgs: [
    #   # python312Packages.tkinter
    # ];
    runners = {
      linux.settings.system.mangohud = true;
      wine.settings = {
        # Points to ~/.local/share/lutris/runners/wine/ge-proton (unmanaged).
        runner = {
          version = "ge-proton";
          battleye = false;
          eac = false;
          fsr = false;
          system_winetricks = true;
        };
        system.mangohud = true;
      };
    };
  };
}
