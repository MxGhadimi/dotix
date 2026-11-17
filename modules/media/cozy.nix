{...}: {
  flake.homeModules.cozy = {pkgs, ...}: {
    home.packages = [pkgs.cozy];
  };
}
