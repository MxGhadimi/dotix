{...}: {
  flake.nixosModules.ci = {lib, ...}: {
    options.custom.ci.buildable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
}
