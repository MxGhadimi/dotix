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
}
