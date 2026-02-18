{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.opencode;

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
        command = ["bunx" "@playwright/mcp@latest" "--browser" "chromium"];
        enabled = true;
      };
    };

    plugin = [
      "oh-my-opencode"
      "opencode-antigravity-auth"
      "opencode-openai-codex-auth"
      "opencode-plugin-openspec"
      "@franlol/opencode-md-table-formatter@0.0.3"
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
        models = {
          "gpt-5.2" = {
            name = "GPT 5.2 (OAuth)";
            limit = {
              context = 272000;
              output = 128000;
            };
            modalities = {
              input = ["text" "image"];
              output = ["text"];
            };
            variants = {
              none = {
                reasoningEffort = "none";
                reasoningSummary = "auto";
                textVerbosity = "medium";
              };
              low = {
                reasoningEffort = "low";
                reasoningSummary = "auto";
                textVerbosity = "medium";
              };
              medium = {
                reasoningEffort = "medium";
                reasoningSummary = "auto";
                textVerbosity = "medium";
              };
              high = {
                reasoningEffort = "high";
                reasoningSummary = "detailed";
                textVerbosity = "medium";
              };
              xhigh = {
                reasoningEffort = "xhigh";
                reasoningSummary = "detailed";
                textVerbosity = "medium";
              };
            };
          };
          "gpt-5.2-codex" = {
            name = "GPT 5.2 Codex (OAuth)";
            limit = {
              context = 272000;
              output = 128000;
            };
            modalities = {
              input = ["text" "image"];
              output = ["text"];
            };
            variants = {
              low = {
                reasoningEffort = "low";
                reasoningSummary = "auto";
                textVerbosity = "medium";
              };
              medium = {
                reasoningEffort = "medium";
                reasoningSummary = "auto";
                textVerbosity = "medium";
              };
              high = {
                reasoningEffort = "high";
                reasoningSummary = "detailed";
                textVerbosity = "medium";
              };
              xhigh = {
                reasoningEffort = "xhigh";
                reasoningSummary = "detailed";
                textVerbosity = "medium";
              };
            };
          };
          "gpt-5.1-codex-max" = {
            name = "GPT 5.1 Codex Max (OAuth)";
            limit = {
              context = 272000;
              output = 128000;
            };
            modalities = {
              input = ["text" "image"];
              output = ["text"];
            };
            variants = {
              low = {
                reasoningEffort = "low";
                reasoningSummary = "detailed";
                textVerbosity = "medium";
              };
              medium = {
                reasoningEffort = "medium";
                reasoningSummary = "detailed";
                textVerbosity = "medium";
              };
              high = {
                reasoningEffort = "high";
                reasoningSummary = "detailed";
                textVerbosity = "medium";
              };
              xhigh = {
                reasoningEffort = "xhigh";
                reasoningSummary = "detailed";
                textVerbosity = "medium";
              };
            };
          };
        };
      };
    };
  };

  # Secret overlay — merged into baseSettings at template render time
  secretSettings = {
    mcp.context7.headers.CONTEXT7_API_KEY =
      config.sops.placeholder."context7-api-key";
  };

  # Platform-specific binary info
  binaryInfo =
    {
      "aarch64-darwin" = {
        filename = "opencode-darwin-arm64.zip";
        hash = "sha256-XpzJD02E3hRbQJnHZmsPB4KxnlGWeVGBysNr4z28Xak=";
        isZip = true;
      };
      "x86_64-darwin" = {
        filename = "opencode-darwin-x64.zip";
        hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Update on first use
        isZip = true;
      };
      "x86_64-linux" = {
        filename = "opencode-linux-x64.tar.gz";
        hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Update on first use
        isZip = false;
      };
      "aarch64-linux" = {
        filename = "opencode-linux-arm64.tar.gz";
        hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Update on first use
        isZip = false;
      };
    }.${
      pkgs.system
    } or (throw "Unsupported system: ${pkgs.system}");

  # Binary download for latest release
  opencodeLatestBinary = pkgs.stdenv.mkDerivation {
    pname = "opencode";
    version = "latest";

    src = pkgs.fetchurl {
      url = "https://github.com/sst/opencode/releases/latest/download/${binaryInfo.filename}";
      hash = binaryInfo.hash;
    };

    nativeBuildInputs =
      if binaryInfo.isZip
      then [pkgs.unzip]
      else [pkgs.gnutar pkgs.gzip];

    unpackPhase =
      if binaryInfo.isZip
      then "unzip $src"
      else "tar -xzf $src";

    installPhase = ''
      mkdir -p $out/bin
      cp opencode $out/bin/
      chmod +x $out/bin/opencode
    '';

    meta = {
      description = "AI coding assistant";
      homepage = "https://github.com/sst/opencode";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };

in {
  imports = [
    ./opencode-profiles.nix
  ];

  options.custom.opencode = {
    useLatest = lib.mkEnableOption "use latest GitHub binary instead of nixpkgs";
  };

  config = {
    home.packages = [pkgs.bun];

    # Package install + enable (config.json managed by sops.templates below)
    programs.opencode = {
      enable = true;
      package = lib.mkIf cfg.useLatest opencodeLatestBinary;
    };

    # Decrypt Context7 API key via sops-nix
    sops.secrets."context7-api-key" = {
      sopsFile = ../secrets/shared/secrets.yaml;
    };

    # Render config.json with the secret baked in — no post-generation mutation
    sops.templates."opencode-config" = {
      content = builtins.toJSON (lib.recursiveUpdate baseSettings secretSettings);
      path = "${config.xdg.configHome}/opencode/config.json";
    };

    # Install Playwright Chromium browser for MCP server
    home.activation.installPlaywrightBrowsers = lib.hm.dag.entryAfter ["writeBoundary"] ''
      ${pkgs.bun}/bin/bunx playwright install chromium 2>/dev/null || echo "Note: Playwright browser install deferred to first use"
    '';
  };
}
