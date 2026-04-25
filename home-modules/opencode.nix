{
  config,
  lib,
  pkgs,
  ...
}: let
  # OpenCode config — defined here so we can inject sops secrets via template
  baseSettings = {
    "$schema" = "https://opencode.ai/config.json";

    mcp = {
      context7 = {
        type = "remote";
        url = "https://mcp.context7.com/mcp";
        enabled = true;
      };
      pdf-reader = {
        type = "local";
        command = ["bunx" "@sylphx/pdf-reader-mcp"];
        enabled = true;
      };
      playwright = {
        type = "local";
        command = ["mcp-server-playwright" "--browser" "chromium"];
        enabled = true;
      };
    };

    plugin = [
      "oh-my-opencode@3.17.4"
      # "superpowers@git+https://github.com/obra/superpowers.git#v5.0.7"
      "@franlol/opencode-md-table-formatter@0.0.6"
    ];

    provider = {
      google = {
        name = "Google";
        models = {
          antigravity-gemini-3-pro-high = {
            name = "Gemini 3 Pro High (Antigravity)";
            thinking = true;
            attachment = true;
            limit = {
              context = 1048576;
              output = 65535;
            };
            modalities = {
              input = ["text" "image" "pdf"];
              output = ["text"];
            };
          };
          antigravity-gemini-3-pro-low = {
            name = "Gemini 3 Pro Low (Antigravity)";
            thinking = true;
            attachment = true;
            limit = {
              context = 1048576;
              output = 65535;
            };
            modalities = {
              input = ["text" "image" "pdf"];
              output = ["text"];
            };
          };
          antigravity-gemini-3-flash = {
            name = "Gemini 3 Flash (Antigravity)";
            attachment = true;
            limit = {
              context = 1048576;
              output = 65536;
            };
            modalities = {
              input = ["text" "image" "pdf"];
              output = ["text"];
            };
          };
        };
      };

      openai = {
        name = "OpenAI";
        options = {
          reasoningEffort = "medium";
          reasoningSummary = "auto";
          textVerbosity = "medium";
          include = ["reasoning.encrypted_content"];
          store = false;
        };
      };
    };
  };

  # Secret overlay — merged into baseSettings at template render time
  secretSettings = {
    mcp.context7.headers.CONTEXT7_API_KEY =
      config.sops.placeholder."context7-api-key";
  };
in {
  imports = [
    ./opencode-config.nix
  ];

  config = {
    home.packages = [pkgs.bun pkgs.playwright-mcp];
    # Package install + enable (config.json managed by sops.templates below)
    programs.opencode.enable = true;
    sops.secrets."context7-api-key" = {
      sopsFile = ../secrets/shared/secrets.yaml;
    };
    # Render config.json with the secret baked in — no post-generation mutation
    sops.templates."opencode-config" = {
      content = builtins.toJSON (lib.recursiveUpdate baseSettings secretSettings);
      path = "${config.xdg.configHome}/opencode/config.json";
    };
  };
}
