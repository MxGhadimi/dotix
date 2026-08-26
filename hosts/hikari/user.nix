{config, ...}: {
  users.users.masaroshi = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
    ];
    hashedPasswordFile = config.sops.secrets.userPassword.path;
  };

  home-manager.users.masaroshi = {
    home = {
      username = "masaroshi";
      homeDirectory = "/home/masaroshi";
      stateVersion = "26.05";
    };
  };
}
