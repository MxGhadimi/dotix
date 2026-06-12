{self, ...}: {
  flake.homeModules.niri = {pkgs, ...}: {
    home.packages = with pkgs; [
      grim
      slurp
      satty
      wl-clipboard
      self.packages.${pkgs.stdenv.hostPlatform.system}.noctalia
      xwayland-satellite
      aria2
      papirus-icon-theme
    ];

    home.sessionVariables = {
      QT_QPA_PLATFORMTHEME = "gtk3";
      QS_ICON_THEME = "Papirus";
    };

    xdg.configFile."niri/config.kdl".source = ./config.kdl;
  };
}
