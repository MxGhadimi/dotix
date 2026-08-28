{config, ...}: {
  users.users.masaroshi = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "i2c"
    ];
    hashedPasswordFile = config.sops.secrets.userPassword.path;
  };
}
