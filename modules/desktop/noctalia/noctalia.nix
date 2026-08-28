{inputs, ...}: {
  flake.homeModules.noctalia = {
    pkgs,
    hostname,
    ...
  }: let
    raw = builtins.fromJSON (builtins.readFile (./. + "/${hostname}.json"));
    settings = raw.settings or raw;
  in {
    home.packages = [
      (inputs.wrapper-modules.wrappers.noctalia-shell.wrap {
        inherit pkgs settings;
      })
    ];

    xdg.configFile."noctalia/settings.json" = {
      text = builtins.toJSON settings;
      force = true;
    };
  };
}
