{
  lib,
  pkgs,
  ...
}: let
  bridgeName = "incusbr0";
  bridgeIpv4Address = "10.100.0.1/24";

  # Keep TrueNAS pool creation disabled for the first install. The installed host
  # should first prove: boot -> key preseed -> sops secret decrypt -> CLI test.
  # Then flip this to true and rebuild.
  enableTrueNasPool = false;

  trueNasPoolName = "truenas";
  trueNasSource = "192.168.1.88:spirit-spring/incus/4Ubuntu";
  trueNasConfigFile = "/run/secrets/rendered/truenas-incus-ctl-config";
  trueNasRootDiskSize = "256GiB";

in {
  networking.nftables = {
    enable = true;
    flushRuleset = false;
  };

  networking.firewall.trustedInterfaces = [bridgeName];

  virtualisation.incus = {
    enable = true;

    preseed = {
      networks = [
        {
          name = bridgeName;
          type = "bridge";
          config = {
            "ipv4.address" = bridgeIpv4Address;
            "ipv4.nat" = "true";
            "ipv6.address" = "none";
          };
        }
      ];

      storage_pools = lib.optionals enableTrueNasPool [
        {
          name = trueNasPoolName;
          driver = "truenas";
          config = {
            source = trueNasSource;
            "truenas.config" = trueNasConfigFile;
            "truenas.force_reuse" = "false";
          };
        }
      ];

      profiles = [
        {
          name = "default";
          devices = {
            eth0 = {
              name = "eth0";
              network = bridgeName;
              type = "nic";
            };
          } // lib.optionalAttrs enableTrueNasPool {
            root = {
              path = "/";
              pool = trueNasPoolName;
              size = trueNasRootDiskSize;
              type = "disk";
            };
          };
        }
        {
          name = "4ubuntu-vm";
          description = "Policy for the imported 4Ubuntu VM";
          config = {
            "limits.cpu" = "8";
            "limits.memory" = "16GiB";
            "boot.autostart" = "true";
          };
          devices = lib.optionalAttrs enableTrueNasPool {
            root = {
              path = "/";
              pool = trueNasPoolName;
              size = "256GiB";
              type = "disk";
            };
          };
        }
      ];
    };
  };

  services.openiscsi = {
    enable = true;
    name = "iqn.2026-06.dev.4nix:server-zant";
  };

  # Incus' TrueNAS storage driver shells out to truenas_incus_ctl. Adding it only
  # to environment.systemPackages is not enough for the systemd daemon.
  systemd.services.incus.path = [pkgs.truenas-incus-ctl];

  environment.systemPackages = with pkgs; [
    incus
    jq
    lvm2
    qemu-utils
    truenas-incus-ctl
  ];
}
