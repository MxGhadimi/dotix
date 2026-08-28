{pkgs, ...}: {
  networking.hostName = "kage";
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "26.05";

  boot.supportedFilesystems = ["ntfs"];

  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/16FC55F1FC55CB9D";
    fsType = "ntfs3";
    options = [
      "rw"
      "uid=1000"
      "gid=100"
      "umask=022"
      "windows_names"
      "nofail"
      "x-systemd.automount"
    ];
  };

  fileSystems."/mnt/windows" = {
    device = "/dev/disk/by-uuid/C402148B02148518";
    fsType = "ntfs3";
    options = [
      "ro"
      "uid=1000"
      "gid=100"
      "umask=022"
      "nofail"
      "x-systemd.automount"
    ];
  };

  hardware.i2c.enable = true;
  environment.systemPackages = [pkgs.ddcutil];
}
