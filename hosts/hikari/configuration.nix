{pkgs, ...}: {
  networking = {
    hostName = "hikari";
    networkmanager.wifi.powersave = true;
  };

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "26.05";

  boot.supportedFilesystems = ["ntfs"];

  fileSystems."/mnt/windows" = {
    device = "/dev/disk/by-uuid/24D054AFD0548946";
    fsType = "ntfs3";
    options = [
      "ro"
      "uid=1000"
      "gid=100"
      "umask=022"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=10min"
    ];
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  boot.kernelParams = [
    "acpi_backlight=native"
    "amd_pstate=active"
  ];

  environment.systemPackages = [pkgs.brightnessctl];

  services = {
    udev = {
      packages = [pkgs.brightnessctl];

      # no wifi wakeup from s2idle
      extraRules = ''
        ACTION=="add", SUBSYSTEM=="net", KERNEL=="wl*|en*|eth*", ATTR{power/wakeup}="disabled"
        ACTION=="add", SUBSYSTEM=="pci", DRIVER=="mt7925e", ATTR{power/wakeup}="disabled"
      '';
    };

    power-profiles-daemon.enable = true;
    fstrim.enable = true;

    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "suspend";
    };
  };
}
