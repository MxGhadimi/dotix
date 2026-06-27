{inputs, ...}: {
  flake.nixosModules.secrets = {config, ...}: {
    imports = [inputs.sops-nix.nixosModules.sops];

    sops = {
      defaultSopsFile = "${inputs.nix-secrets}/hosts/${config.networking.hostName}/secrets.yaml";
      defaultSopsFormat = "yaml";
      age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

      secrets = {
        userPassword = {
          neededForUsers = true;
        };

        github_ssh_key = {
          path = "/home/masaroshi/.ssh/github";
          mode = "0600";
          owner = "masaroshi";
          group = "users";
        };

        github_ssh_key_pub = {
          path = "/home/masaroshi/.ssh/github.pub";
          mode = "0644";
          owner = "masaroshi";
          group = "users";
        };
      };
    };
  };
}
