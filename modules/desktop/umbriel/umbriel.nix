{inputs, ...}: {
  flake.homeModules.umbriel = {
    hostname,
    pkgs,
    ...
  }: {
    imports = [inputs.umbriel.homeModules.default];

    home.packages = [pkgs.kdePackages.qt6ct];

    programs.umbriel = {
      enable = true;
      settings = ./. + "/${hostname}.toml";
    };
  };
}
