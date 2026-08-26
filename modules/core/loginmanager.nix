{...}: {
  flake.nixosModules.loginmanager = {
    lib,
    config,
    ...
  }: {
    options.custom.display.defaultSession = lib.mkOption {
      type = lib.types.str;
      default = "niri";
    };

    config.services.displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };
      defaultSession = config.custom.display.defaultSession;
    };
  };
}
