{...}: {
  flake.nixosModules.hardware-nvidia = {
    config,
    pkgs,
    ...
  }: {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        libva-vdpau-driver
        nvidia-vaapi-driver
      ];
    };

    services.xserver.videoDrivers = ["nvidia"];

    hardware.nvidia = {
      open = true;
      modesetting.enable = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
    };

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "nvidia";
    };

    environment.systemPackages = [
      pkgs.nvitop
    ];
  };
}
