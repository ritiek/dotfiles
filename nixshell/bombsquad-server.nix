with import <nixpkgs> {};
  mkShell {
    # NIX_LD = lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker";
    NIX_LD_LIBRARY_PATH = lib.makeLibraryPath [
      python312
      stdenv.cc.cc
    ];

    buildInputs = [
      python312
    ];

    # shellHook = ''
    #   ./bombsquad_server
    # '';
  }
