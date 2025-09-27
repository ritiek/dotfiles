{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./bme680.nix
  ];
}