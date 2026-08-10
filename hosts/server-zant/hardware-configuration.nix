{...}: {
  # Temporary hardware module so the server-zant flake target can evaluate before
  # the real NixOS install. Keep disk/filesystem layout in ./disko.nix; merge only
  # useful hardware-specific settings from nixos-generate-config after first boot.

  boot.initrd.availableKernelModules = [
    "hpsa"
    "ehci_pci"
    "uhci_hcd"
    "ahci"
    "sd_mod"
    "sr_mod"
  ];

  boot.kernelModules = ["kvm-intel"];

}
