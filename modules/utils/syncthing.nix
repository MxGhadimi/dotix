{...}: {
  flake.nixosModules.syncthing = {config, ...}: {
    services.syncthing = {
      enable = true;
      user = "masaroshi";
      guiAddress = "127.0.0.1:8385";
      group = "users";
      configDir = "${config.users.users.masaroshi.home}/.config/syncthing";
      openDefaultPorts = true;
      overrideDevices = false;
      overrideFolders = false;
    };
  };
}
