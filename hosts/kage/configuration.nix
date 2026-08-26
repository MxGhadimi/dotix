{pkgs, ...}: {
  networking.hostName = "kage";
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "26.05";

  hardware.i2c.enable = true;
  environment.systemPackages = [pkgs.ddcutil];
}
