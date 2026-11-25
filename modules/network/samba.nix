{...}: {
  flake.nixosModules.samba = {...}: {
    services.samba = {
      enable = true;
      openFirewall = false;

      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "security" = "user";
          "server min protocol" = "SMB2";
        };

        shared = {
          "path" = "/home/masaroshi/shared";
          "browseable" = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "valid users" = "masaroshi";
        };
      };
    };

    services.samba-wsdd = {
      enable = true;
      openFirewall = true;
    };

    networking.firewall.allowedTCPPorts = [445];
  };
}