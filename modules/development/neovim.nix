{...}: {
  flake.homeModules.neovim = {...}: {
    programs.neovim.enable = true;

    xdg.configFile."nvim/init.lua" = {
      source = ./nvim/init.lua;
      force = true;
    };

    xdg.configFile."nvim/lua" = {
      source = ./nvim/lua;
      recursive = true;
      force = true;
    };
  };
}
