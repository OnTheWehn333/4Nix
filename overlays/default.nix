{ inputs, ... }: {
  # Expose nixpkgs-unstable under pkgs.unstable
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };

  # Packages you want to override live here 👇
  modifications = final: prev: { };
}
