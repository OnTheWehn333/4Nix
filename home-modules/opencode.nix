{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.opencode;

  # Read API key from external file at runtime
  # Create this file with: echo "your-api-key" > ~/.secrets/context7-api-key
  secretsDir = "${config.home.homeDirectory}/.secrets";

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

  # oh-my-opencode configuration
  ohMyOpencodeSettings = {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
    google_auth = false;
    agents = {
      sisyphus = {model = "opencode/claude-opus-4-6";};
      prometheus = {model = "opencode/claude-opus-4-6";};
      librarian = {model = "google/antigravity-gemini-3-flash";};
      explore = {model = "google/antigravity-gemini-3-flash";};
      frontend-ui-ux-engineer = {model = "google/antigravity-gemini-3-pro-high";};
      document-writer = {model = "google/antigravity-gemini-3-flash";};
      multimodal-looker = {model = "google/antigravity-gemini-3-flash";};
    };
  };
in {
  options.custom.opencode = {
    useLatest = lib.mkEnableOption "use latest GitHub binary instead of nixpkgs";
  };

  config = {
    home.packages = [pkgs.bun];

    # Upstream programs.opencode handles enable, package, settings, and config.json
    programs.opencode = {
      enable = true;
      package = lib.mkIf cfg.useLatest opencodeLatestBinary;

      settings = {
        mcp = {
          context7 = {
            type = "remote";
            url = "https://mcp.context7.com/mcp";
            # headers will be injected by activation script
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
    };

    # oh-my-opencode config (not handled by upstream)
    xdg.configFile."opencode/oh-my-opencode.json".text = builtins.toJSON ohMyOpencodeSettings;

    # Install Playwright Chromium browser for MCP server
    home.activation.installPlaywrightBrowsers = lib.hm.dag.entryAfter ["writeBoundary"] ''
      ${pkgs.bun}/bin/bunx playwright install chromium 2>/dev/null || echo "Note: Playwright browser install deferred to first use"
    '';

    # Activation script to inject API key into config.json
    home.activation.injectOpencodeSecrets = lib.hm.dag.entryAfter ["writeBoundary"] ''
      OPENCODE_CONFIG="${config.xdg.configHome}/opencode/config.json"
      SECRETS_FILE="${secretsDir}/context7-api-key"

      if [ -f "$SECRETS_FILE" ] && [ -f "$OPENCODE_CONFIG" ]; then
        API_KEY=$(cat "$SECRETS_FILE" | tr -d '\n')
        # Use jq to inject the API key into the headers
        ${pkgs.jq}/bin/jq --arg key "$API_KEY" '.mcp.context7.headers = {"CONTEXT7_API_KEY": $key}' \
          "$OPENCODE_CONFIG" > "$OPENCODE_CONFIG.tmp" && mv "$OPENCODE_CONFIG.tmp" "$OPENCODE_CONFIG"
        $DRY_RUN_CMD echo "Injected Context7 API key into opencode config"
      else
        if [ ! -f "$SECRETS_FILE" ]; then
          echo "Warning: Context7 API key not found at $SECRETS_FILE"
          echo "Create it with: mkdir -p ${secretsDir} && echo 'your-api-key' > $SECRETS_FILE && chmod 600 $SECRETS_FILE"
        fi
      fi
    '';
  };
}
