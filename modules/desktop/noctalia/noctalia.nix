{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    packages.noctalia = inputs.wrapper-modules.wrappers.noctalia-shell.wrap {
      inherit pkgs;
      inherit ((builtins.fromJSON (builtins.readFile ./noctalia.json))) settings;
    };
  };
}
