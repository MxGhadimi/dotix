{lib, ...}: {
  flake.nixosModules.llm = {
    pkgs,
    config,
    ...
  }: {
    config = lib.mkIf (!config.custom.ci.buildable) {
      services.ollama = {
        enable = true;
        package = pkgs.ollama-cuda;
      };

      environment.systemPackages = with pkgs; [
        ollama-cuda
        oterm
        (llama-cpp.override {cudaSupport = true;})
      ];

      services.open-webui = {
        enable = true;
        port = 42069;
      };
    };
  };
}
