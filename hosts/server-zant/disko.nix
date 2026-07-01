{
  lib,
  ...
}: {
  # Destructive disk layout for the HP ProLiant DL380p Gen8 local OS disk.
  # This is the current XCP-ng boot disk. Only apply this when intentionally
  # retiring/wiping XCP-ng on server-zant.
  #
  # Layout: legacy-BIOS GRUB on GPT, with one ext4 root filesystem.
  disko.devices.disk.os = {
    type = "disk";
    device = lib.mkDefault "/dev/disk/by-id/wwn-0x600508b1001c1c12bd1ca0c65bb3541c";
    content = {
      type = "gpt";
      partitions = {
        biosBoot = {
          size = "1M";
          type = "EF02";
          priority = 1;
        };

        root = {
          size = "100%";
          priority = 2;
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            extraArgs = ["-L" "NIXROOT"];
          };
        };
      };
    };
  };
}
