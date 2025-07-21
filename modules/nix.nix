{ config, ... }:
{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    substituters = [
      "https://nix-community.cachix.org"
      "https://numtide.cachix.org"
      "https://cache.garnix.io"
      "https://cache.nixos.org"
      "https://nixpkgs-wayland.cachix.org"
      # "https://nabam-nixos-rockchip.cachix.org"
      "https://hyprland.cachix.org"

      "http://pilab.lion-zebra.ts.net:7080/attic-action"
      # In case my server is not reachable over Tailscale.
      "https://attic.clawsiecats.omg.lol/attic-action"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      # "nabam-nixos-rockchip.cachix.org-1:BQDltcnV8GS/G86tdvjLwLFz1WeFqSk7O9yl+DR0AVM="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "attic-action:wjnBtx68f8TU7eahRKpVICGlIwOjQ7ENsCUiDd5Jqqs="
    ];
    trusted-users = [ "ritiek" ];
    # Fallback to building from source when cache server is not accessible.
    fallback = true;
  };
}
