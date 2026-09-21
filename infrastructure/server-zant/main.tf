locals {
  bridge_name         = "incusbr0"
  truenas_pool_name   = "truenas"
  truenas_source      = "spirit-spring/server-zant"
  truenas_config_name = "truenas"
  truenas_initiator   = "2"
  truenas_portal      = "1"
}

resource "incus_server" "server_zant" {
  config = {
    "core.https_address" = "0.0.0.0:8443"
  }

  lifecycle {
    prevent_destroy = true
  }
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
    "truenas.config"      = local.truenas_config_name
    "truenas.force_reuse" = "false"
    "truenas.initiator"   = local.truenas_initiator
    "truenas.portal"      = local.truenas_portal
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

resource "incus_image" "server_gohdan" {
  count = var.enable_server_gohdan ? 1 : 0

  source_file = {
    data_path     = "${abspath(var.server_gohdan_image_directory)}/disk.qcow2"
    metadata_path = "${abspath(var.server_gohdan_image_directory)}/metadata.tar.xz"
  }

  # Incus provider 1.1.1 does not preserve alias descriptions when reading a
  # locally imported image, which causes an inconsistent-result apply failure.
  alias {
    name = "server-gohdan-nixos"
  }
}

resource "incus_profile" "server_gohdan_vm" {
  count = var.enable_server_gohdan ? 1 : 0

  name        = "server-gohdan-vm"
  description = "Identity VM policy for server-gohdan"

  config = {
    "boot.autostart"      = "true"
    "limits.cpu"          = tostring(var.server_gohdan_cpu_count)
    "limits.memory"       = var.server_gohdan_memory
    "security.secureboot" = "false"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "incus_instance" "server_gohdan" {
  count = var.enable_server_gohdan ? 1 : 0

  name     = "server-gohdan"
  type     = "virtual-machine"
  image    = incus_image.server_gohdan[0].fingerprint
  profiles = [incus_profile.default.name, incus_profile.server_gohdan_vm[0].name]
  running  = true

  device {
    name = "eth0"
    type = "nic"

    properties = {
      name           = "eth0"
      network        = incus_network.incusbr0.name
      "ipv4.address" = var.server_gohdan_ipv4_address
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [image]

    precondition {
      condition     = var.enable_truenas_pool
      error_message = "server-gohdan requires the validated TrueNAS storage pool."
    }
  }
}
