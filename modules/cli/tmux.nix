{...}: {
  flake.homeModules.tmux = {...}: {
    programs.tmux.enable = true;
  };
}
