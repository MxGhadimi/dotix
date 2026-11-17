{...}: {
  flake.homeModules.readest = {pkgs, ...}: {
    home.packages = [pkgs.readest];
  };
}
