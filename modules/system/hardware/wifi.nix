{...}: {
  flake.nixosModules.hardware-wifi = {...}: {
    networking.networkmanager.enable = true;
    hardware.wirelessRegulatoryDatabase = true;
  };
}
