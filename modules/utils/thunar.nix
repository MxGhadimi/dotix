{...}: {
  flake.nixosModules.thunar = {...}: {
    programs.thunar.enable = true;
  };
}
