{ pkgs, ... }:

# Pinned replacement for nur.repos.nltch.spotify-adblock.
# The NUR package fetches `refs/heads/main` of abba23/spotify-adblock with a
# fixed hash, so it breaks every time upstream pushes a new commit
# (https://github.com/NL-TCH/nur-packages/issues/33). This pins an exact
# revision instead.
let
  spotify-adblock = pkgs.rustPlatform.buildRustPackage {
    pname = "spotify-adblock";
    version = "1.0.3-unstable-2026-08-14";
    src = pkgs.fetchFromGitHub {
      owner = "abba23";
      repo = "spotify-adblock";
      rev = "0f1873638f5dd0ccd62741a518bbe4ccc7670cf9";
      hash = "sha256-zQiEByj/OjOMgy3JSjk3RyPAX//yYt/2s84f5Ok1uTI=";
    };
    cargoHash = "sha256-IZ1KCEV2tljCsdmNGZ53nE4PCxcVuGLL5sk9UYWZWK0=";

    patchPhase = ''
      substituteInPlace src/config.rs \
        --replace-fail 'const GLOBAL_CONFIG_DIR: &str = "/etc";' \
                  "const GLOBAL_CONFIG_DIR: &str = \"$out/etc\";"
    '';

    buildPhase = ''
      make
    '';

    installPhase = ''
      mkdir -p $out/etc/spotify-adblock
      install -D --mode=644 config.toml $out/etc/spotify-adblock
      mkdir -p $out/lib
      install -D --mode=644 --strip target/release/libspotifyadblock.so $out/lib
    '';
  };

  spotify-adblocked = pkgs.spotify.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.zip pkgs.unzip ];
    postInstall =
      (old.postInstall or "")
      + ''
        ln -s ${spotify-adblock}/lib/libspotifyadblock.so $libdir
        sed -i "s:^Name=Spotify.*:Name=Spotify-adblock:" "$out/share/spotify/spotify.desktop"
        wrapProgram $out/bin/spotify \
          --set LD_PRELOAD "${spotify-adblock}/lib/libspotifyadblock.so"

        # Hide placeholder for advert banner
        ${pkgs.unzip}/bin/unzip -p $out/share/spotify/Apps/xpui.spa xpui-snapshot.js | sed 's/adsEnabled:\!0/adsEnabled:false/' > $out/share/spotify/Apps/xpui-snapshot.js
        ${pkgs.zip}/bin/zip --junk-paths --update $out/share/spotify/Apps/xpui.spa $out/share/spotify/Apps/xpui-snapshot.js
        rm $out/share/spotify/Apps/xpui-snapshot.js
      '';
  });

in
{
  _module.args.spotify-adblock-pkg = spotify-adblocked;

  home.packages = [ spotify-adblocked ];
}
