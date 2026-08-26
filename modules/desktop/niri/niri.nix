{...}: {
  flake.homeModules.niri = {
    pkgs,
    osConfig,
    ...
  }: {
    home.packages = with pkgs; [
      grim
      slurp
      satty
      wl-clipboard
      xwayland-satellite
      aria2
      papirus-icon-theme
      brightnessctl
    ];

    home.sessionVariables = {
      QS_ICON_THEME = "Papirus";
    };

    xdg.configFile."niri/config.kdl".source =
      ./. + "/${osConfig.networking.hostName}.kdl";
  };
}
