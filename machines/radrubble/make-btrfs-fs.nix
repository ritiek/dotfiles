# nixpkgs' make-btrfs-fs.nix wraps mkfs.btrfs in fakeroot, but btrfs-progs
# 7.x bypasses it, so every file in the image ends up owned by the nixbld
# build user instead of root (NetworkManager then refuses its plugins, nix
# can't write temproots, ...). Run mkfs.btrfs in a user namespace instead,
# which maps the build user to uid 0 at the kernel level.
{ pkgs, lib, util-linux, ... }@args:

(pkgs.callPackage (pkgs.path + "/nixos/lib/make-btrfs-fs.nix")
  (removeAttrs args [ "pkgs" "lib" "util-linux" ])).overrideAttrs (old: {
  nativeBuildInputs = old.nativeBuildInputs ++ [ util-linux ];
  buildCommand = builtins.replaceStrings
    [ "fakeroot mkfs.btrfs" ] [ "unshare -r mkfs.btrfs" ]
    old.buildCommand;
})
