{inputs, ...}: {
  # Expose nixpkgs-unstable under pkgs.unstable
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };

  # Packages you want to override live here 👇
  modifications = final: prev: {
    opencode = final.unstable.opencode;
    azure-cli = final.unstable.azure-cli;

    httpgenerator = final.buildDotnetGlobalTool {
      pname = "HttpGenerator";
      version = "1.0.0";
      nugetHash = "sha256-JESESLRyPmcK7XZowL0GOxkezGPBQqsZ54AeaCB4RKQ=";
      dotnet-runtime = final.dotnetCorePackages.runtime_8_0;
      executables = [ "httpgenerator" ];
    };

    tmuxPlugins = prev.tmuxPlugins // {
      tome = prev.tmuxPlugins.mkTmuxPlugin {
        pluginName = "tome";
        version = "unstable-2025-10-08";
        src = final.fetchFromGitHub {
          owner = "laktak";
          repo = "tome";
          rev = "4c4b31eeb8e8e12d1493a88b3870a257c7d15667";
          hash = "sha256-7ZbaFWQ3bNi2M40xp6cwySuEr0K7cOX1jeX7FwLf6Us=";
        };
      };
    };
  };
}
