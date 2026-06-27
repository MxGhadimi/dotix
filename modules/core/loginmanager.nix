{...}: {
  flake.nixosModules.loginmanager = {...}: {
    services = {
      displayManager = {
        sddm = {
          enable = true;
          wayland.enable = true;
        };
        defaultSession = "niri";
      };
      desktopManager.plasma6.enable = true;
    };
  };
}
