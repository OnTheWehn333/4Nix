locals {
  bridge_name       = "incusbr0"
  truenas_pool_name = "truenas"
  truenas_source    = "spirit-spring/server-zant"
  truenas_config    = "/run/secrets/rendered/truenas-incus-ctl-config"
}

resource "incus_network" "incusbr0" {
  name = local.bridge_name
  type = "bridge"

  config = {
    "ipv4.address" = "10.100.0.1/24"
    "ipv4.nat"     = "true"
    "ipv6.address" = "none"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "incus_storage_pool" "truenas" {
  count = var.enable_truenas_pool ? 1 : 0

  name   = local.truenas_pool_name
  driver = "truenas"

  config = {
    source                = local.truenas_source
    "truenas.config"      = local.truenas_config
    "truenas.force_reuse" = "false"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "incus_profile" "default" {
  name        = "default"
  description = "Default Incus profile"

  device {
    name = "eth0"
    type = "nic"

    properties = {
      name    = "eth0"
      network = incus_network.incusbr0.name
    }
  }

  dynamic "device" {
    for_each = var.enable_truenas_pool ? incus_storage_pool.truenas[*].name : []

    content {
      name = "root"
      type = "disk"

      properties = {
        path = "/"
        pool = device.value
        size = var.default_root_disk_size
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "incus_profile" "four_ubuntu_vm" {
  name        = "4ubuntu-vm"
  description = "Policy for the imported 4Ubuntu VM"

  config = {
    "boot.autostart" = "true"
    "limits.cpu"     = "8"
    "limits.memory"  = "16GiB"
  }

  lifecycle {
    prevent_destroy = true
  }
}
