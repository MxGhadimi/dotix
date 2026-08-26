{...}: {
  flake.nixosModules.refind = {
    pkgs,
    lib,
    config,
    ...
  }: let
    host = config.networking.hostName;
    theme = config.custom.refind.theme;
  in {
    options.custom.refind.theme = lib.mkOption {
      # boot/refind/themes/{theme}
      type = lib.types.str;
    };

    config = {
      # systemd-boot files stay (rEFInd chainloads them). Don't let it own NVRAM.
      boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

      environment.systemPackages = [pkgs.refind pkgs.efibootmgr];

      system.activationScripts.refind = lib.stringAfter ["etc"] ''
        mkdir -p /boot/EFI/refind/themes
        ${pkgs.rsync}/bin/rsync -a ${pkgs.refind}/share/refind/refind_x64.efi /boot/EFI/refind/refind_x64.efi
        ${pkgs.rsync}/bin/rsync -a ${./refind + "/${host}.conf"} /boot/EFI/refind/refind.conf
        ${pkgs.rsync}/bin/rsync -a --delete \
          ${./refind/themes + "/${theme}"}/ \
          /boot/EFI/refind/themes/${theme}/
      '';

      systemd.services.refind-efi = {
        description = "Register rEFInd EFI boot entry";
        wantedBy = ["multi-user.target"];
        after = ["local-fs.target"];
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        path = [pkgs.efibootmgr pkgs.util-linux pkgs.gnugrep pkgs.gnused pkgs.coreutils];
        script = ''
          set -eu
          if ! efibootmgr | grep -qi rEFInd; then
            esp=$(findmnt -n -o SOURCE /boot)
            disk=/dev/$(lsblk -no pkname "$esp")
            part=$(basename "$esp" | grep -oE '[0-9]+$')
            efibootmgr --create \
              --disk "$disk" --part "$part" \
              --label rEFInd \
              --loader '\EFI\refind\refind_x64.efi'
          fi
          id=$(efibootmgr | sed -n 's/^Boot\([0-9A-Fa-f]*\).*rEFInd.*/\1/Ip' | head -n1)
          others=$(efibootmgr | sed -n 's/^BootOrder: //p' | sed "s/$id,//g; s/,$id//; s/$id//")
          if [ -n "$id" ]; then
            efibootmgr --bootorder "$id''${others:+,$others}" || true
          fi
        '';
      };
    };
  };
}
