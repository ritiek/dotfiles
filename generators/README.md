# Generators

Generates ISO image files. Integrated with GitHub actions to build and upload artifacts
so they can be downloaded later.

## minimal-iso

```
$ nix build '.#minimal-iso'
$ ls ./result/iso/nixos.iso
```

## minimal-install-iso

```
$ nix build '.#minimal-install-iso'
$ ls ./result/iso/*.iso
```
