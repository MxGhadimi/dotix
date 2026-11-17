{...}: {
  flake.nixosModules.shell = {...}: {
    programs.zsh.enable = true;
  };

  flake.homeModules.shell = {pkgs, ...}: let
    sigil = pkgs.stdenv.mkDerivation {
      pname = "sigil";
      version = "1.0";
      src = ./sigil.c;
      dontUnpack = true;
      buildInputs = [pkgs.zlib];

      buildPhase = ''
        runHook preBuild
        $CC -O3 -fno-math-errno -std=c11 "$src" -o sigil -lm -lz
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        install -Dm755 sigil $out/bin/sigil
        runHook postInstall
      '';
    };
    sigilGreeting = ''
      if [ -t 1 ] && [ -n "''${GHOSTTY_RESOURCES_DIR:-}" ] && [ -z "''${TMUX:-}" ] && [ -z "''${SIGIL_SHOWN:-}" ]; then
        export SIGIL_SHOWN=1
        sigil --dither 4
      fi
    '';
  in {
    programs = {
      zsh = {
        enable = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        initContent = sigilGreeting;
      };

      bash = {
        enable = true;
        initExtra = sigilGreeting;
      };

      starship.enable = true;
    };

    home.packages = with pkgs; [
      fastfetch
      yazi
      btop
      sops
      age
      wget
      sigil
    ];
  };
}
