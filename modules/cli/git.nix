{...}: {
  flake.homeModules.git = {config, ...}: {
    programs.git = {
      enable = true;
      settings = {
        core.editor = "nvim";
        user.name = "mxghadimi";
        user.email = "mxghadimi@gmail.com";
        init.defaultBranch = "main";
        diff.algorithm = "histogram";
      };
    };

    programs.ssh.matchBlocks = {
      "github.com" = {
        user = "git";
        identityFile = "${config.home.homeDirectory}/.ssh/github";
        identitiesOnly = true;
      };
    };
  };
}
