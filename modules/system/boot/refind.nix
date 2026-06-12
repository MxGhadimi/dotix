{...}: {
  flake.nixosModules.refind = {
    pkgs,
    lib,
    ...
  }: {
    environment.systemPackages = [
      pkgs.refind
      pkgs.efibootmgr
    ];

    environment.etc."refind.conf" = {
      target = "../boot/EFI/refind/refind.conf";
      source = ./refind/refind.conf;
    };

    system.activationScripts.refindTheme = lib.stringAfter ["etc"] ''
      mkdir -p /boot/EFI/refind/themes
      ${pkgs.rsync}/bin/rsync -a --delete \
        ${
        builtins.path {
          path = ./refind/themes/rEFInd-minimal-rog;
          name = "refind-theme";
        }
      }/ \
        /boot/EFI/refind/themes/rEFInd-minimal-rog/
    '';
  };
}
