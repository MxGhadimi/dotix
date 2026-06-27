{...}: {
  flake.nixosModules.shell = {...}: {
    programs.zsh.enable = true;
  };

  flake.homeModules.shell = {pkgs, ...}: {
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
    };
    programs.starship.enable = true;
    home.packages = with pkgs; [
      fastfetch
      yazi
      btop
      sops
      age
      wget
    ];
  };
}
