{...}: {
  flake.homeModules.neovim = {...}: {
    programs.neovim = {
      enable = true;
      initLua = builtins.readFile ./nvim/init.lua;
    };

    xdg.configFile."nvim/lua".source = ./nvim/lua;
  };
}
