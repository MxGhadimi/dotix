{lib, ...}: {
  flake.nixosModules.packettracer = {
    pkgs,
    config,
    ...
  }: {
    config = lib.mkIf (!config.custom.ci.buildable) {
      environment.systemPackages = with pkgs; [ciscoPacketTracer9];
    };
  };
}
