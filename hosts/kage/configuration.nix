{...}: {
  networking.hostName = "kage";
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "26.05";
}
