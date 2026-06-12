_: {
  flake.nixosModules.locale = {...}: {
    time.timeZone = "Asia/Tehran";
    i18n.defaultLocale = "en_US.UTF-8";
  };
}
