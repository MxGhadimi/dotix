{...}: {
  flake.nixosModules.core = {self, ...}: {
    imports = [
      self.nixosModules.nix-settings
      self.nixosModules.locale
      self.nixosModules.fonts
      self.nixosModules.loginmanager
      self.nixosModules.ssh
      self.nixosModules.secrets
      self.nixosModules.ci
    ];
  };
}
