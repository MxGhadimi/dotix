{...}: {
  flake.nixosModules.packettracer = {
    pkgs,
    lib,
    ...
  }: {
    environment.systemPackages =
      lib.optionals (builtins.getEnv "CI" != "true") # skip  gh actions runner
      
      (with pkgs; [ciscoPacketTracer9]);
  };
}
