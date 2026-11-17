{...}: {
  flake.nixosModules.fonts = {pkgs, ...}: let
    winterDraw = pkgs.stdenvNoCC.mkDerivation {
      pname = "winter-draw-font";
      version = "1.0.0";
      src = ../fonts/WinterDraw.ttf;
      dontUnpack = true;
      dontBuild = true;
      installPhase = ''
        install -Dm644 "$src" "$out/share/fonts/truetype/WinterDraw.ttf"
      '';
      meta = {
        description = "Winter Draw typeface by Khurasan";
        license = pkgs.lib.licenses.unfree;
        platforms = pkgs.lib.platforms.linux;
      };
    };
  in {
    fonts.packages = [
      winterDraw
      pkgs.noto-fonts-cjk-sans
    ];
  };
}
