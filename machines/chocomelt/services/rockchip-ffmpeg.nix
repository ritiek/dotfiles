# jellyfin-ffmpeg with Rockchip MPP (hardware decode/encode) and RGA (hardware
# scaling), shared by jellyfin (./nixarr.nix) and frigate (./frigate.nix).
pkgs:

let
  # Rockchip MPP/RGA userspace at the commits jellyfin-ffmpeg's own builder
  # pins (builder/scripts.d/50-rkmpp.sh, 50-rkrga.sh).
  rkMirrors = rev: hash: pkgs.fetchFromGitHub {
    owner = "nyanmisaka";
    repo = "rk-mirrors";
    inherit rev hash;
  };
  rockchip-mpp = pkgs.stdenv.mkDerivation {
    pname = "rockchip-mpp";
    version = "jellyfin-a9380ef";
    src = rkMirrors "a9380ef333102ac318628f83b5f7a460d377749e" "sha256-W18KrNdd1HNcubDv0K+CmAEdbXiqB5y0ECb0FUefUrk=";
    nativeBuildInputs = [ pkgs.cmake ];
    # Its .pc files do ${prefix}/@CMAKE_INSTALL_LIBDIR@, so keep the dirs relative.
    cmakeFlags = [ "-DBUILD_TEST=OFF" "-DCMAKE_INSTALL_LIBDIR=lib" "-DCMAKE_INSTALL_INCLUDEDIR=include" ];
  };
  librga = pkgs.stdenv.mkDerivation {
    pname = "librga";
    version = "jellyfin-1d330cc";
    src = rkMirrors "1d330cc28551943bed3380261a5a9c6fbd58ff53" "sha256-EO/YvkyaAgIyAZQJjXa8b5SEgCo4vfDpYoeKcJH1n4o=";
    nativeBuildInputs = with pkgs; [ meson ninja pkg-config ];
    mesonFlags = [ "-Dcpp_args=-fpermissive" "-Dlibdrm=false" "-Dlibrga_demo=false" ];
  };
in
pkgs.jellyfin-ffmpeg.overrideAttrs (old: {
  buildInputs = old.buildInputs ++ [ rockchip-mpp librga ];
  configureFlags = old.configureFlags ++ [ "--enable-rkmpp" "--enable-rkrga" ];
})
