{...}: {
  flake.homeModules.archive = {pkgs, ...}: {
    home.packages = with pkgs; [
      xarchiver
      p7zip
    ];
  };
}
