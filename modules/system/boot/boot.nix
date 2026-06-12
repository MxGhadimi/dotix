{...}: {
  flake.nixosModules.boot = {pkgs, ...}: {
    boot = {
      loader = {
        efi.canTouchEfiVariables = true;
        systemd-boot.enable = true;
      };
      supportedFilesystems = ["ntfs"];
      kernelPackages = pkgs.linuxPackages_latest;
    };
  };
}
