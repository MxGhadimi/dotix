{...}: {
  flake.homeModules.neovim = {...}: {
    programs.neovim.enable = true;

    xdg = {
      desktopEntries.nvim = {
        # route through Ghostty with the class niri expects
        name = "Neovim";
        comment = "Edit text";
        exec = "ghostty --class=com.mitchellh.ghostty.nvim -e nvim %F";
        icon = "nvim";
        terminal = false;
        categories = ["TextEditor" "Development"];
        type = "Application";
      };
      configFile."nvim/init.lua" = {
        source = ./nvim/init.lua;
        force = true;
      };
      configFile."nvim/lua" = {
        source = ./nvim/lua;
        recursive = true;
        force = true;
      };
    };
  };
}
