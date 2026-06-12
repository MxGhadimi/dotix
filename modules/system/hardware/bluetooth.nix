{...}: {
  flake.nixosModules.hardware-bluetooth = {...}: {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    services.blueman.enable = true;
  };
}
