{inputs, ...}: {
  flake.homeModules.noctalia = {
    config,
    hostname,
    lib,
    ...
  }: {
    imports = [inputs.noctalia.homeModules.default];

    programs.noctalia = {
      enable = true;
      settings = ./. + "/${hostname}.toml";
    };

    xdg.configFile."noctalia/templates/niri.kdl".text = ''
      layout {
          focus-ring {
              active-color "{{colors.terminal_background.default.hex}}"
              inactive-color "{{colors.terminal_background.default.hex}}"
              urgent-color "{{colors.error.default.hex}}"
          }

          border {
              active-color "{{colors.primary.default.hex}}"
              inactive-color "{{colors.surface_variant.default.hex}}"
              urgent-color "{{colors.error.default.hex}}"
          }

          tab-indicator {
              active-color "{{colors.secondary.default.hex}}"
              inactive-color "{{colors.primary_container.default.hex}}"
              urgent-color "{{colors.error.default.hex}}"
          }

          insert-hint {
              color "{{colors.primary.default.hex}}80"
          }
      }

      recent-windows {
          highlight {
              active-color "{{colors.primary.default.hex}}"
              urgent-color "{{colors.error.default.hex}}"
          }
      }
    '';

    home.activation.ensureNiriThemeOutput = lib.hm.dag.entryAfter ["linkGeneration"] ''
      themeFile="${config.xdg.configHome}/niri/noctalia.kdl"
      if [ ! -e "$themeFile" ] && [ ! -L "$themeFile" ]; then
        $DRY_RUN_CMD mkdir -p "$(dirname "$themeFile")"
        $DRY_RUN_CMD touch "$themeFile"
        $DRY_RUN_CMD chmod 0644 "$themeFile"
      fi
    '';
  };
}
