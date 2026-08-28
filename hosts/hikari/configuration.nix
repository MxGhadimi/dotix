{pkgs, ...}: {
  networking = {
    hostName = "hikari";
    networkmanager.wifi.powersave = true;
  };

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "26.05";

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
