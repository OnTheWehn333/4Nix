{lib, ...}: {
  # Temporary placeholder so the server-zant flake target can evaluate before
  # the real NixOS install. Replace this file with nixos-generate-config output
  # from the HP ProLiant DL380p Gen8 during the final install.

  boot.initrd.availableKernelModules = [
    "hpsa"
    "ehci_pci"
    "uhci_hcd"
    "ahci"
    "sd_mod"
    "sr_mod"
  ];

  boot.kernelModules = ["kvm-intel"];

  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
}
