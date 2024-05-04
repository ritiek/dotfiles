with import <nixpkgs> {};
  mkShell {
    # NIX_LD = lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker";
    NIX_LD_LIBRARY_PATH = lib.makeLibraryPath [
      python312
      SDL2
      libvorbis
      libGL
      openal
      stdenv.cc.cc
    ];

    # shellHook = ''
    #   ./bombsquad
    # '';
  }
