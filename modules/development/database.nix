{...}: {
  flake.nixosModules.database = {pkgs, ...}: {
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
    };

    environment.systemPackages = with pkgs; [
      sqlite
    ];
  };
}
