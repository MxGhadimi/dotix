{...}: {
  flake.nixosModules.cachix-agent = {config, ...}: {
    sops.secrets."cachix/agent-token" = {};

    sops.templates."cachix-agent.env".content = ''
      CACHIX_AGENT_TOKEN="${config.sops.placeholder."cachix/agent-token"}"
    '';

    services.cachix-agent = {
      enable = true;
      credentialsFile = config.sops.templates."cachix-agent.env".path;
    };
  };
}
